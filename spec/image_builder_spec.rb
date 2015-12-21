require "spec_helper"
require "aytests/image_builder"
require "aytests/iso_repo"

RSpec.describe AYTests::ImageBuilder do
  let(:work_dir) { TEST_WORK_DIR }
  let(:sources_dir) { Pathname.new(__FILE__).dirname.join("..", "share", "veewee") }
  let(:files_dir) { TEST_WORK_DIR.join("files") }
  let(:autoinst_path) { Pathname.new(__FILE__).dirname.join("files", "autoinst.xml") }
  let(:iso_url) { "http://dl.opensuse.org/leap-42.1.iso" }
  let(:path_to_iso) { work_dir.join("iso", "leap-42.1.iso") }
  let(:provider) { :libvirt }
  let(:local_ip) { "192.168.122.232" }

  let(:default_args) do
    { sources_dir: sources_dir, work_dir: work_dir, files_dir: files_dir,
      provider: provider, headless: true }
  end

  subject(:builder) { AYTests::ImageBuilder.new(default_args) }

  describe ".new" do
    context "when no provider is given" do
      let(:default_args) { { sources_dir: sources_dir, work_dir: work_dir } }

      it "selects :libvirt" do
        expect(builder.provider).to eq(:libvirt)
      end
    end

    context "when a provider is given" do
      let(:default_args) { { sources_dir: sources_dir, work_dir: work_dir, provider: :virtualbox } }

      it "selects the given provider" do
        expect(builder.provider).to eq(:virtualbox)
      end
    end
  end

  describe "#veewee_autoyast_dir" do
    it "returns work_dir + /definitions/autoyast" do
      expect(builder.veewee_autoyast_dir)
        .to eq(work_dir.join("definitions", "autoyast"))
    end
  end

  describe "#autoinst_path" do
    it "returns work_dir + /definitions/autoyast/autoinst.xml" do
      expect(builder.autoinst_path)
        .to eq(work_dir.join("definitions", "autoyast", "autoinst.xml"))
    end
  end

  describe "#definition_path" do
    it "returns work_dir + /definitions/autoyast/definition.rb" do
      expect(builder.definition_path)
        .to eq(work_dir.join("definitions", "autoyast", "definition.rb"))
    end
  end

  describe "#libvirt_definition_path" do
    it "returns work_dir + /definitions/autoyast/autoyast_description.xml" do
      expect(builder.libvirt_definition_path)
        .to eq(work_dir.join("definitions", "autoyast", "autoyast_description.xml"))
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

      # Uses Veewee provider
      expect(builder).to receive(:veewee_provider).at_least(1).and_return(:kvm)

      # Build
      expect(builder).to receive(:system)
        .with({"AYTESTS_FILES_DIR" => files_dir.to_s, "AYTESTS_LINUXRC" => "vnc=1",
               "AYTESTS_MAC_ADDRESS" => "02:00:00:12:34:56", "AYTESTS_PROVIDER" => provider.to_s,
               "AYTESTS_WEBSERVER_PORT" => "8888"},
               "veewee kvm build #{AYTests::ImageBuilder::IMAGE_NAME} --force --auto --nogui")
        .and_return(true)

      # Prepare the AutoYaST profile
      expect(builder).to receive(:local_ip)
        .and_return(local_ip)

      #
      # Perform the installation
      #
      expect(builder.install(autoinst_path, iso_url)).to eq(true)

      # Check that AutoYaST profile, Veewee definition and post-install script
      # were available
      expect(File).to be_file(builder.veewee_autoyast_dir.join("postinstall.sh"))
      expect(File).to be_file(builder.definition_path)
      expect(File).to be_file(builder.autoinst_path)
      autoinst_content = File.read(builder.autoinst_path)

      # Check if variables were replaced
      expect(autoinst_content)
        .to include("http://#{local_ip}:#{AYTests::ImageBuilder::WEBSERVER_PORT}/repos/sles12")
      expect(autoinst_content)
        .to_not include("REPO1_URL")
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

      expect(builder).to receive(:change_boot_order)
      expect(builder).to receive(:backup_image)

      # Prepare the AutoYaST profile
      expect(builder).to receive(:local_ip)
        .and_return(local_ip)

      # Run post-install script
      expect(builder).to receive(:run_postinstall)

      # Build
      expect(builder).to receive(:system)
        .with({"AYTESTS_FILES_DIR" => files_dir.to_s, "AYTESTS_LINUXRC" => "vnc=1",
               "AYTESTS_MAC_ADDRESS" => "02:00:00:12:34:56", "AYTESTS_PROVIDER" => provider.to_s,
               "AYTESTS_WEBSERVER_PORT" => "8888"},
               "veewee kvm build #{AYTests::ImageBuilder::IMAGE_NAME} --force --auto --nogui")
        .and_return(true)

      allow(builder).to receive(:sleep)

      #
      # Perform the upgrade
      #
      expect(builder.upgrade(autoinst_path, iso_url)).to eq(true)

      # Check that AutoYaST profile, Veewee definition and post-install script
      # were available
      expect(File).to be_file(builder.veewee_autoyast_dir.join("postinstall.sh"))
      expect(File).to be_file(builder.definition_path)
      expect(File).to be_file(builder.autoinst_path)
      # Check if variables were replaced
      autoinst_content = File.read(builder.autoinst_path)
      expect(autoinst_content)
        .to include("http://#{local_ip}:#{AYTests::ImageBuilder::WEBSERVER_PORT}/repos/sles12")
      expect(autoinst_content)
        .to_not include("REPO1_URL")
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
    before(:each) do
      FileUtils.mkdir_p(TEST_WORK_DIR)
    end

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
