require "spec_helper"
require "aytests/image_builder"
require "aytests/iso_repo"

RSpec.describe AYTests::ImageBuilder do
  let(:base_dir) { Pathname.new(File.dirname(__FILE__)).join("..") }
  let(:autoinst_path) { base_dir.join("autoinst.xml") }
  let(:iso_url) { "http://dl.opensuse.org/leap-42.1.iso" }
  let(:path_to_iso) { base_dir.join("iso", "leap-42.1.iso") }
  let(:provider) { :libvirt }
  let(:local_ip) { "192.168.122.232" }

  subject(:builder) { AYTests::ImageBuilder.new(base_dir: base_dir, provider: provider) }

  describe ".new" do
    context "when no base directory is given" do
      it "takes the base directory from AYTests module" do
        expect(AYTests).to receive(:base_dir).and_return(base_dir)
        builder = AYTests::ImageBuilder.new
        expect(builder.base_dir).to eq(base_dir)
      end
    end

    context "when a base directory is given" do
      it "is used as base directory" do
        expect(AYTests).not_to receive(:base_dir)
        builder = AYTests::ImageBuilder.new(base_dir: Pathname.new("/some-directory"))
        expect(builder.base_dir).to eq(Pathname.new("/some-directory"))
      end
    end

    context "when no provider is given" do
      subject(:builder) do
        AYTests::ImageBuilder.new(base_dir: base_dir)
      end

      it "selects :libvirt" do
        expect(builder.provider).to eq(:libvirt)
      end
    end

    context "when a provider is given" do
      subject(:builder) do
        AYTests::ImageBuilder.new(base_dir: base_dir, provider: :virtualbox)
      end

      it "selects the given provider" do
        expect(builder.provider).to eq(:virtualbox)
      end
    end
  end

  describe "#obs_iso_dir" do
    it "returns base_dir + /kiwi/iso" do
      expect(builder.obs_iso_dir).to eq(base_dir.join("kiwi", "iso"))
    end
  end

  describe "#kiwi_autoyast_dir" do
    it "returns base_dir + /kiwi/definitions/autoyast" do
      expect(builder.kiwi_autoyast_dir)
        .to eq(base_dir.join("kiwi", "definitions", "autoyast"))
    end
  end

  describe "#autoinst_path" do
    it "returns base_dir + /kiwi/definitions/autoyast/autoinst.xml" do
      expect(builder.autoinst_path)
        .to eq(base_dir.join("kiwi", "definitions", "autoyast", "autoinst.xml"))
    end
  end

  describe "#definition_path" do
    it "returns base_dir + /kiwi/definitions/autoyast/definition.rb" do
      expect(builder.definition_path)
        .to eq(base_dir.join("kiwi", "definitions", "autoyast", "definition.rb"))
    end
  end

  describe "#libvirt_definition_path" do
    it "returns base_dir + /kiwi/autoyast_description.xml" do
      expect(builder.libvirt_definition_path)
        .to eq(base_dir.join("kiwi", "autoyast_description.xml"))
    end
  end

  describe "#install" do
    it "runs each building phase and returns true if build was successful" do
      # Retrieve and link ISO
      expect(AYTests::IsoRepo).to receive(:get).with(iso_url)
        .and_return(path_to_iso)
      expect(FileUtils).to receive(:rm)
        .with(builder.obs_iso_dir.join("testing.iso"), force: true)
      expect(FileUtils).to receive(:ln_s)
        .with(path_to_iso, builder.obs_iso_dir.join("testing.iso"))

      # Copy AutoYaST profile and Veewee definition
      expect(FileUtils).to receive(:cp)
        .with(builder.kiwi_autoyast_dir.join("install_definition.rb"), builder.definition_path)
      expect(autoinst_path).to receive(:file?).and_return(true)
      expect(FileUtils).to receive(:cp)
        .with(autoinst_path, builder.autoinst_path)

      # Uses Veewee provider
      expect(builder).to receive(:veewee_provider).at_least(1).and_return(:kvm)

      # Build
      expect(builder).to receive(:system)
        .with("veewee kvm build #{AYTests::ImageBuilder::IMAGE_NAME} --force --auto --nogui")
        .and_return(true)

      # Prepare the AutoYaST profile
      expect(builder).to receive(:local_ip)
        .and_return(local_ip)
      expect(builder).to receive(:system)
        .with("sed -e 's/%IP%/#{local_ip}/g' -i #{builder.autoinst_path}")
        .and_return(true)

      expect(builder.install(autoinst_path, iso_url)).to eq(true)
    end
  end

  describe "#upgrade" do
    it "runs each building phase and returns true if build was successful" do
      # Retrieve and link ISO
      expect(AYTests::IsoRepo).to receive(:get).with(iso_url)
        .and_return(path_to_iso)
      expect(FileUtils).to receive(:rm)
        .with(builder.obs_iso_dir.join("testing.iso"), force: true)
      expect(FileUtils).to receive(:ln_s)
        .with(path_to_iso, builder.obs_iso_dir.join("testing.iso"))

      # Copy AutoYaST profile and Veewee definition
      expect(FileUtils).to receive(:cp)
        .with(builder.kiwi_autoyast_dir.join("upgrade_definition.rb"), builder.definition_path)
      expect(autoinst_path).to receive(:file?).and_return(true)
      expect(FileUtils).to receive(:cp)
        .with(autoinst_path, builder.autoinst_path)

      expect(builder).to receive(:change_boot_order)
      expect(builder).to receive(:backup_image)

      # Prepare the AutoYaST profile
      expect(builder).to receive(:local_ip)
        .and_return(local_ip)
      expect(builder).to receive(:system)
        .with("sed -e 's/%IP%/#{local_ip}/g' -i #{builder.autoinst_path}")
        .and_return(true)

      # Run post-install script
      expect(builder).to receive(:run_postinstall)

      # Build
      expect(builder).to receive(:system)
        .with("veewee kvm build #{AYTests::ImageBuilder::IMAGE_NAME} --force --auto --nogui")
        .and_return(true)

      allow(builder).to receive(:sleep)

      expect(builder.upgrade(autoinst_path, iso_url)).to eq(true)
    end
  end

  describe "#import" do
    before do
      allow(builder).to receive(:export_from_veewee).and_return(true)
    end

    it "imports the machine using Vagrant and returns true if it was successful" do
      expect(builder).to receive(:system).with(/vagrant box add/).and_return(true)
      expect(builder.import).to eq(true)
    end

    it "tries to import machine using Vagrant and returns false if it wasn't successful" do
      expect(builder).to receive(:system).with(/vagrant box add/).and_return(false)
      expect(builder.import).to eq(false)
    end
  end

  describe "#export_from_veewee" do
    it "relies on Veewee and returns true if it was successful" do
      expect(builder).to receive(:system).with(/veewee kvm export/).and_return(true)
      expect(builder.export_from_veewee).to eq(true)
    end

    it "relies on Veewee and returns false if it was not successful" do
      expect(builder).to receive(:system).with(/veewee kvm export/).and_return(false)
      expect(builder.export_from_veewee).to eq(false)
    end
  end

  describe "#cleanup" do
    context "when provider is :libvirt" do
      it "removes copied AutoYaST profile, Veewee definition and vm storage" do
        expect(FileUtils).to receive(:rm).with(builder.autoinst_path, force: true)
        expect(FileUtils).to receive(:rm).with(builder.definition_path, force: true)
        expect(FileUtils).to receive(:rm).with(builder.libvirt_definition_path, force: true)
        expect(builder).to receive(:system)
          .with("sudo virsh vol-delete #{AYTests::ImageBuilder::IMAGE_BOX_NAME} default")
          .and_return(false)
        builder.cleanup
      end
    end

    context "when provider is :virtualbox" do
      let(:provider) { :virtualbox }

      it "removes copied AutoYaST profile, Veewee definition" do
        expect(FileUtils).to receive(:rm).with(builder.autoinst_path, force: true)
        expect(FileUtils).to receive(:rm).with(builder.definition_path, force: true)
        expect(FileUtils).to receive(:rm).with(builder.libvirt_definition_path, force: true)
        expect(builder).to_not receive(:system)
        builder.cleanup
      end
    end
  end

  describe "#veewee_provider" do
    context "when given provider is :libvirt" do
      it "returns :kvm" do
        expect(builder.veewee_provider).to eq(:kvm)
      end
    end

    context "when given provider is :virtualbox" do
      let(:provider) { :virtualbox }

      it "returns :vbox" do
        expect(builder.veewee_provider).to eq(:vbox)
      end
    end
  end
end
