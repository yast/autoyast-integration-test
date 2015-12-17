require "spec_helper"
require "aytests/definition"

RSpec.describe AYTests::Definition do
  LIBVIRT_VM = File.join(File.dirname(__FILE__), "files", "autoyast-libvirt.xml")
  VIRTUALBOX_VM = File.join(File.dirname(__FILE__), "files", "autoyast-virtualbox.txt")

  context "when the provider is :libvirt" do
    describe ".import" do
      let(:xml) { File.read(LIBVIRT_VM) }

      it "returns a definition containing imported data from Libvirt" do
        allow(Cheetah).to receive(:run).
          with(["sudo", "virsh", "dumpxml", "autoyast"], stdout: :capture).
          and_return(xml)

        definition = AYTests::Definition.import("autoyast", :libvirt)
        expect(definition.mac).to eq("52:54:00:8a:98:c4")
        expect(definition.name).to eq("autoyast")
        expect(definition.provider).to eq(:libvirt)
      end
    end
  end

  context "when the provider is :virtualbox" do
    describe ".import" do
      let(:xml) { File.read(VIRTUALBOX_VM) }

      it "returns a definition containing imported data from VirtualBox" do
        allow(Cheetah).to receive(:run).
          with(%w(VBoxManage showvminfo --machinereadable autoyast), stdout: :capture).
          and_return(xml)

        definition = AYTests::Definition.import("autoyast", :virtualbox)
        expect(definition.mac).to eq("08:00:27:96:36:49")
        expect(definition.name).to eq("autoyast")
        expect(definition.provider).to eq(:virtualbox)
      end
    end
  end

  describe "#mac=" do
    subject(:definition) { AYTests::Definition.new(provider: :libvirt, name: "autoyast") }

    let(:mac) { "080027963A49" }

    it "stores the MAC as a downcase string using ':' as separator" do
      definition.mac = mac
      expect(definition.mac).to eq("08:00:27:96:3a:49")
    end
  end
end
