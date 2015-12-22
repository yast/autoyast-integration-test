require "spec_helper"
require "aytests/libvirt_vm"

RSpec.describe AYTests::LibvirtVM do
  LIBVIRT_DEFINITION = File.join(File.dirname(__FILE__), "files", "autoyast-libvirt.xml")

  subject { AYTests::LibvirtVM.new("autoyast") }
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
end
