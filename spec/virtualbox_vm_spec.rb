require "spec_helper"
require "aytests/virtualbox_vm"

RSpec.describe AYTests::VirtualboxVM do
  VIRTUALBOX_DEFINITION = File.join(File.dirname(__FILE__), "files", "autoyast-virtualbox.txt")

  subject { AYTests::VirtualboxVM.new("autoyast") }
  let(:definition) { File.read(VIRTUALBOX_DEFINITION) }

  before do
    allow(Cheetah).to receive(:run).
      with(["VBoxManage", "showvminfo", "--machinereadable", "autoyast"], stdout: :capture).
      and_return(definition)
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
        .with(["VBoxManage", "modifyvm", "autoyast", "--macaddress1", "12:34:56:78:90:ab",
               "--boot1", "disk", "--boot2", "dvd", "--boot3", "none", "--boot4", "none"])
      subject.save
    end
  end
end
