require "spec_helper"
require "aytests/vm"
require "aytests/libvirt_vm"
require "pathname"

RSpec.describe AYTests::VM do
  subject(:vm) { AYTests::VM.new(vm_name, :libvirt) }

  let(:vm_name) { "autoyast" }
  let(:driver) { double("driver", mac: mac) }
  let(:ip) { "192.168.122.50" }
  let(:mac) { "52:54:00:8a:98:c4" }

  before do
    allow(AYTests::LibvirtVM).to receive(:new).with(vm_name).and_return(driver)
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

  describe "#screenshot" do
    it "relies on driver #screenshot method" do
      path = Pathname("screenshot.png")
      expect(driver).to receive(:screenshot).with(path)
      subject.screenshot(path)
    end
  end

  describe "#update" do
    let(:values) { { mac: "00:00:00:12:34:56", boot_order: [:hd, :cdrom] } }

    it "updates values and saves the machine" do
      expect(subject).to receive(:mac=).with(values[:mac])
      expect(subject).to receive(:boot_order=).with(values[:boot_order])
      expect(driver).to receive(:save)
      subject.update(values)
    end
  end

  describe "#run" do
    let(:user) { "vagrant" }
    let(:port) { 22 }
    let(:password) { "123456" }
    let(:result) { { exit_code: 0 } }

    before do
      allow(subject).to receive(:ip).and_return(ip)
      allow(Net::SSH::Simple).to receive(:ssh).and_return(result)
    end

    it "runs the given command on the VM through SSH" do
      expect(Net::SSH::Simple).to receive(:ssh)
        .with(subject.ip, "ls", port: port, user: user, password: password, paranoid: false)
      subject.run("ls", port: port, user: user, password: password)
    end

    it "returns true" do
      expect(subject.run("ls", port: port, user: user, password: password)).to eq(true)
    end

    context "when command fails" do
      let(:result) { { exit_code: 127 } }

      it "returns false" do
        expect(subject.run("unknown", port: port, user: user, password: password)).to eq(false)
      end
    end

    context "when command raises an exception" do
      before do
        allow(Net::SSH::Simple).to receive(:ssh).and_raise(Net::SSH::Simple::Error.new("failed"))
      end

      it "returns false" do
        expect(subject.run("ls", port: port, user: user, password: password)).to eq(false)
      end
    end
  end

  describe "#download" do
    let(:user) { "vagrant" }
    let(:port) { 22 }
    let(:password) { "123456" }
    let(:source) { Pathname.new("/tmp/y2logs.tgz") }
    let(:target) { Pathname.new("y2logs.tgz") }

    before do
      allow(subject).to receive(:ip).and_return(ip)
      allow(Net::SSH::Simple).to receive(:scp_get)
    end

    it "downloads the file from the virtual machine" do
      expect(Net::SSH::Simple).to receive(:scp_get)
        .with(subject.ip, source.to_s, target.to_s, port: port, user: user, password: password,
        paranoid: false)
      subject.download(source, target, port: port, user: user, password: password)
    end

    it "returns true" do
      expect(subject.download(source, target, port: port, user: user, password: password))
        .to eq(true)
    end

    context "when command fails" do
      before do
        allow(Net::SSH::Simple).to receive(:scp_get)
          .and_raise(Net::SSH::Simple::Error.new("failed"))
      end

      it "returns false" do
        expect(subject.download(source, target, port: port, user: user, password: password))
          .to eq(false)
      end
    end
  end

  describe "#ip" do
    before do
      allow(Cheetah).to receive(:run)
        .with(["arp", "-n"], stdout: :capture)
        .and_return(File.read(FIXTURES_PATH.join("arp.txt")))
    end

    it "returns the IP address" do
      expect(subject.ip).to eq("192.168.122.94")
    end
  end
end
