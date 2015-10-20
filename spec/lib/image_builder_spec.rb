require "spec_helper"
require "ay_tests/image_builder"
require "ay_tests/iso_repo"

RSpec.describe AYTests::ImageBuilder do
  let(:base_dir) { Pathname.new(File.dirname(__FILE__)).join("..", "..") }
  let(:autoinst_path) { base_dir.join("autoinst.xml") }
  let(:iso_url) { "http://dl.opensuse.org/leap-42.1.iso" }
  let(:path_to_iso) { base_dir.join("iso", "leap-42.1.iso") }

  subject(:builder) { AYTests::ImageBuilder.new(base_dir) }

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
        builder = AYTests::ImageBuilder.new(Pathname.new("/some-directory"))
        expect(builder.base_dir).to eq(Pathname.new("/some-directory"))
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

      # Build
      expect(builder).to receive(:system)
        .with("veewee kvm build #{AYTests::ImageBuilder::IMAGE_NAME} --force --auto")
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

      # Build
      expect(builder).to receive(:system)
        .with("veewee kvm build #{AYTests::ImageBuilder::IMAGE_NAME} --force --auto")
        .and_return(true)

      expect(builder.upgrade(autoinst_path, iso_url)).to eq(true)
    end
  end

  describe "#export" do
    it "relies on Veewee and returns true if it was successful" do
      expect(builder).to receive(:system).with(/veewee kvm export/).and_return(true)
      expect(builder.export).to eq(true)
    end

    it "relies on Veewee and returns false if it was not successful" do
      expect(builder).to receive(:system).with(/veewee kvm export/).and_return(false)
      expect(builder.export).to eq(false)
    end
  end
end
