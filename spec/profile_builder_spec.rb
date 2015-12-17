require "spec_helper"
require "aytests/profile_builder"

RSpec.describe AYTests::ProfileBuilder do
  subject(:builder) { AYTests::ProfileBuilder.new(name, autoinst_path, provider) }

  let(:name) { "autoyast" }
  let(:autoinst_path) { File.join(File.dirname(__FILE__), "files", "autoinst.xml") }

  describe "#build" do
    let(:profile) { builder.build }

    let(:definition) { double("definition", name: name, mac: mac) }
    let(:local_ip) { "10.0.0.2" }
    let(:mac) { "12:34:56:78:90:ab" }
    let(:provider) { :libvirt }

    before do
      expect(AYTests::Definition).to receive(:import).
        with(name, provider).
        and_return(definition)
      expect(builder).to receive(:local_ip).and_return(local_ip)
    end

    it "replaces '%MAC%' with machine MAC address" do
      expect(profile).to include(mac)
      expect(profile).to_not include("%MAC%")
    end

    it "replaces '%IP%' with machine local_ip address" do
      expect(profile).to include("10.0.0.2")
      expect(profile).to_not include("%IP%")
    end

    context "when the provider is :libvirt" do
      it "does not replace /dev/vd* devices with /dev/sd*" do
        expect(profile).to include("/dev/vd")
        expect(profile).to_not include("/dev/sd")
      end
    end

    context "when the provider is :virtualbox" do
      let(:provider) { :virtualbox }

      it "replaces /dev/vd* devices with /dev/sd*" do
        expect(profile).to_not include("/dev/vd")
        expect(profile).to include("/dev/sd")
      end
    end
  end
end
