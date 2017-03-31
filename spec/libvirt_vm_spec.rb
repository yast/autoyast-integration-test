require "spec_helper"
require "aytests/libvirt_vm"

RSpec.describe AYTests::LibvirtVM do
  LIBVIRT_DEFINITION = FIXTURES_PATH.join("autoyast-libvirt.xml")
  NAME = "autoyast".freeze

  subject { AYTests::LibvirtVM.new(NAME) }
  let(:definition) { File.read(LIBVIRT_DEFINITION) }

  before do
    allow(Cheetah).to receive(:run).
      with(["sudo", "virsh", "dumpxml", "autoyast"], stdout: :capture).
      and_return(definition)
  end

  describe "#boot_order=" do
    it "sets the boot_order" do
      subject.boot_order = [:cdrom, :hd, :network]
      expect(subject.boot_order).to eq([:cdrom, :hd, :network])
    end
  end

  describe "#boot_order" do
    it "returns the boot order" do
      expect(subject.boot_order).to eq([:hd, :cdrom, :network])
    end
  end

  describe "#mac=" do
    it "sets the MAC address" do
      subject.mac = "01:23:45:67:89:AB"
      expect(subject.mac).to eq("01:23:45:67:89:AB")
    end
  end

  describe "#mac" do
    it "returns the MAC address" do
      expect(subject.mac).to eq("52:54:00:8a:98:c4")
    end
  end

  describe "#save" do
    it "updates the virtual machine using virt-xml" do
      subject.mac = "12:34:56:78:90:ab"
      subject.boot_order = [:hd, :cdrom]
      expect(Cheetah).to receive(:run)
        .with(["sudo", "virt-xml", "autoyast", "--edit", "--network", "mac=12:34:56:78:90:ab"])
      expect(Cheetah).to receive(:run)
        .with(["sudo", "virt-xml", "autoyast", "--edit", "--boot", "hd,cdrom"])
      subject.save
    end
  end

  describe "#backup" do
    before do
      allow(subject).to receive(:running?).and_return(running)
    end

    context "when the machine is not running" do
      let(:running) { false }

      it "clones the machine" do
        expect(subject).to_not receive(:shutdown)
        expect(Cheetah).to receive(:run)
          .with(["sudo", "virt-clone", "-o", "autoyast", "-n", "backup-name", "--auto-clone", "--replace"])
        subject.backup("backup-name")
      end
    end

    context "when the machine is running" do
      let(:running) { true }

      it "shuts down and clones the machine" do
        expect(subject).to receive(:shutdown)
        expect(Cheetah).to receive(:run)
          .with(["sudo", "virt-clone", "-o", "autoyast", "-n", "backup-name", "--auto-clone", "--replace"])
        subject.backup("backup-name")
      end
    end
  end

  describe "#restore!" do
    let(:old_vm) { double("old_vm") }

    before do
      allow(described_class).to receive(:new).with("autoyast").and_call_original
      allow(described_class).to receive(:new).with("backup-name").and_return(old_vm)
    end

    it "restores the given machine into the current one" do
      expect(old_vm).to receive(:destroy!)
      expect(Cheetah).to receive(:run)
        .with(["sudo", "virt-clone", "-o", "backup-name", "-n", "autoyast", "--auto-clone", "--replace"])
      subject.restore!("backup-name")
    end
  end

  describe "#shutdown" do
    let(:running_after_shutdown) { false }

    before do
      expect(subject).to receive(:sleep).and_return(nil)
      allow(subject).to receive(:running?).and_return(running_after_shutdown)
    end

    it "shuts down the machine" do
      expect(Cheetah).to receive(:run).with(["sudo", "virsh", "shutdown", "autoyast"])
      expect(Cheetah).to_not receive(:run).with(["sudo", "virsh", "destroy", "autoyast"])
      subject.shutdown
    end

    context "when a timeout occurs" do
      let(:running_after_shutdown) { true }

      it "powers off the machine" do
        expect(Cheetah).to receive(:run).with(["sudo", "virsh", "shutdown", "autoyast"])
        expect(Cheetah).to receive(:run).with(["sudo", "virsh", "destroy", "autoyast"])
        subject.shutdown
      end
    end
  end

  describe "#running?" do
    before do
      allow(Cheetah).to receive(:run)
        .with(["sudo", "virsh", "domstate", "autoyast"], stdout: :capture)
        .and_return("#{state}\n\n")
    end

    context "the machine is running" do
      let(:state) { "running" }

      it "returns true" do
        expect(subject).to be_running
      end
    end

    context "the machine is not running" do
      let(:state) { "stopped" }

      it "returns false" do
        expect(subject).to_not be_running
      end
    end
  end

  describe "#screenshot" do
    let(:path) { Pathname.new("/tmp/screenshot.png") }

    before do
      allow(MiniMagick::Tool::Convert).to receive(:new)
    end

    it "uses virsh to create a screenshot of the running system" do
      expect(Cheetah).to receive(:run)
        .with(["sudo", "virsh", "screenshot", subject.name, "--file", path.sub_ext(".pnm").to_s])
      expect(MiniMagick::Tool::Convert).to receive(:new)
      subject.screenshot(path)
    end

    context "when screenshot was successfully saved" do
      it "returns true" do
        allow(Cheetah).to receive(:run)
          .with(array_including("screenshot"))
        expect(subject.screenshot(path)).to eq(true)
      end
    end

    context "when screenshot was not successfully saved" do
      before do
        allow(Cheetah).to receive(:run)
          .with(array_including("screenshot"))
          .and_raise(Cheetah::ExecutionFailed.new(["virsh"], 1, nil, nil))
      end

      it "returns false" do
        expect(subject.screenshot(path)).to eq(false)
      end
    end
  end

  describe "#ip" do
    before do
      allow(Cheetah).to receive(:run)
        .with(["sudo", "virsh", "domiflist", NAME], stdout: :capture)
        .and_return(File.read(FIXTURES_PATH.join("domiflist.txt")))
      allow(Cheetah).to receive(:run)
        .with(["arp", "-n"], stdout: :capture)
        .and_return(File.read(FIXTURES_PATH.join("arp.txt")))
    end

    it "returns the IP address" do
      expect(subject.ip).to eq("192.168.122.94")
    end
  end
end
