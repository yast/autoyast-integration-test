require "spec_helper"
require "aytests/virtualbox_vm"

RSpec.describe AYTests::VirtualboxVM do
  VIRTUALBOX_DEFINITION = FIXTURES_PATH.join("autoyast-virtualbox.txt")

  subject { AYTests::VirtualboxVM.new("autoyast") }
  let(:definition) { File.read(VIRTUALBOX_DEFINITION) }

  before do
    allow(Cheetah).to receive(:run)
      .with(["VBoxManage", "showvminfo", "--machinereadable", "autoyast"], stdout: :capture)
      .and_return(definition)
  end

  describe "#boot_order=" do
    it "sets the boot order" do
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
      subject.mac = "08:00:27:96:36:50"
      expect(subject.mac).to eq("08:00:27:96:36:50")
    end
  end

  describe "#mac" do
    it "returns the MAC address" do
      expect(subject.mac).to eq("08:00:27:96:36:49")
    end
  end

  describe "#save" do
    it "updates the virtual machine using VBoxManage" do
      subject.mac = "12:34:56:78:90:ab"
      subject.boot_order = [:hd, :cdrom]
      expect(Cheetah).to receive(:run)
        .with(["VBoxManage", "modifyvm", "autoyast", "--macaddress1", "1234567890ab",
               "--boot1", "disk", "--boot2", "dvd", "--boot3", "none", "--boot4", "none"])
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
          .with(["VBoxManage", "unregistervm", subject.name])
        expect(FileUtils).to receive(:mv)
          .with(Pathname.new("/home/suse/VirtualBox VMs/autoyast"),
            Pathname.new("/home/suse/VirtualBox VMs/autoyast_sav"))
        subject.backup("autoyast_sav")
      end
    end

    context "when the machine is running" do
      let(:running) { true }

      it "shuts down and clones the machine" do
        expect(subject).to receive(:shutdown)
        expect(Cheetah).to receive(:run)
          .with(["VBoxManage", "unregistervm", subject.name])
        expect(FileUtils).to receive(:mv)
          .with(Pathname.new("/home/suse/VirtualBox VMs/autoyast"),
            Pathname.new("/home/suse/VirtualBox VMs/autoyast_sav"))
        subject.backup("autoyast_sav")
      end
    end
  end

  describe "#restore!" do
    let(:old_vm) { double("old_vm") }

    before do
      allow(described_class).to receive(:new).with("autoyast").and_call_original
      allow(described_class).to receive(:new).with("autoyast_sav").and_return(old_vm)
    end

    it "restores the given machine into the current one" do
      expect(Cheetah).to receive(:run)
        .with(["VBoxManage", "unregistervm", subject.name, "--delete"])
      expect(FileUtils).to receive(:mv)
        .with(Pathname.new("/home/suse/VirtualBox VMs/autoyast_sav"),
          Pathname.new("/home/suse/VirtualBox VMs/autoyast"))
      expect(Cheetah).to receive(:run)
        .with(["VBoxManage", "registervm", "/home/suse/VirtualBox VMs/autoyast/autoyast.vbox"])
      subject.restore!("autoyast_sav")
    end
  end

  describe "#shutdown" do
    let(:running_after_shutdown) { false }

    before do
      expect(subject).to receive(:sleep).and_return(nil)
      allow(subject).to receive(:running?).and_return(running_after_shutdown)
    end

    it "shuts down the machine" do
      expect(Cheetah).to receive(:run)
        .with(["VBoxManage", "controlvm", subject.name, "acpipowerbutton"])
      expect(Cheetah).to_not receive(:run)
        .with(["VBoxManage", "controlvm", subject.name, "poweroff"])
      subject.shutdown
    end

    context "when a timeout occurs" do
      let(:running_after_shutdown) { true }

      it "powers off the machine" do
        expect(Cheetah).to receive(:run)
          .with(["VBoxManage", "controlvm", subject.name, "acpipowerbutton"])
        expect(Cheetah).to receive(:run)
          .with(["VBoxManage", "controlvm", subject.name, "poweroff"])
        subject.shutdown
      end
    end
  end

  describe "#running?" do
    before do
      allow(Cheetah).to receive(:run)
        .with(["VBoxManage", "showvminfo", "--machinereadable", "autoyast"],
          ["grep", "VMState"], stdout: :capture)
        .and_return("VMState=\"#{state}\"\n\n")
    end

    context "the machine is running" do
      let(:state) { "running" }

      it "returns true" do
        expect(subject).to be_running
      end
    end

    context "the machine is not running" do
      let(:state) { "poweroff" }

      it "returns false" do
        expect(subject).to_not be_running
      end
    end
  end

  describe "#screenshot" do
    let(:path) { Pathname.new("/tmp/screenshot.png") }

    it "uses VBoxManage to create a screenshot of the running system" do
      expect(Cheetah).to receive(:run)
        .with(["VBoxManage", "controlvm", subject.name, "screenshotpng", path])
      subject.screenshot(path)
    end

    context "when screenshot was successfully saved" do
      it "returns true" do
        allow(Cheetah).to receive(:run)
          .with(array_including("screenshotpng"))
        expect(subject.screenshot(path)).to eq(true)
      end
    end

    context "when screenshot was not successfully saved" do
      before do
        allow(Cheetah).to receive(:run)
          .with(array_including("screenshotpng"))
          .and_raise(Cheetah::ExecutionFailed.new(["VBoxManage"], 1, nil, nil))
      end

      it "returns false" do
        expect(subject.screenshot(path)).to eq(false)
      end
    end
  end
end
