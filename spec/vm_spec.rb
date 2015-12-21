require "spec_helper"
require "aytests/vm"

RSpec.describe AYTests::VM do
  class DummyVM
    def initialize(name); end
  end

  subject(:vm) { AYTests::VM.new(vm_name, :dummy) }

  let(:vm_name) { "autoyast" }
  let(:driver) { double("driver") }

  before do
    allow(AYTests).to receive(:const_get).with("DummyVM").and_return(DummyVM)
    allow(DummyVM).to receive(:new).with(vm_name).and_return(driver)
  end

  describe ".new" do
    it "initializes the driver for the given machine" do
      expect(subject.driver).to eq(driver)
    end
  end

  describe "#name" do
    it "returns the name of the VM" do
      expect(subject.name).to eq(vm_name)
    end
  end

  describe "#mac" do
    it "relies on driver mac method" do
      expect(driver).to receive(:mac).and_return("00:00:00:12:34:56")
      expect(subject.mac).to eq("00:00:00:12:34:56")
    end
  end

  describe "#mac" do
    it "relies on driver #mac= method" do
      expect(driver).to receive(:mac=).with("00:00:00:12:34:56")
      subject.mac = "00:00:00:12:34:56"
    end
  end

  describe "#boot_order" do
    it "relies on driver boot_order method" do
      expect(driver).to receive(:boot_order).and_return([:hd, :cdrom])
      expect(subject.boot_order).to eq([:hd, :cdrom])
    end
  end

  describe "#boot_order" do
    it "relies on driver #boot_order= method" do
      expect(driver).to receive(:boot_order=).with([:hd, :cdrom])
      subject.boot_order = [:hd, :cdrom]
    end
  end
end
