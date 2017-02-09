require "spec_helper"
require "aytests/iso_repo"
require "tmpdir"
require "fileutils"

RSpec.describe AYTests::IsoRepo do
  let(:repo_dir) { Dir.mktmpdir }
  let(:iso_url) { "http://dl.opensuse.org/leap-42.1.iso" }

  subject(:iso_repo) { AYTests::IsoRepo.new(repo_dir) }

  after(:each) do
    FileUtils.rm_rf(repo_dir) if Dir.exist?(repo_dir)
  end

  describe ".init" do
    let(:directory) { double("directory", :directory? => exist?)}

    context "when directory exists" do
      let(:exist?) { true }

      it "returns a new IsoRepo instance" do
        expect(FileUtils).to_not receive(:mkdir_p)
        repo = described_class.init(directory)
        expect(repo).to be_kind_of(described_class)
        expect(repo.dir).to eq(directory)
      end
    end

    context "when directory does not exists" do
      let(:exist?) { true }

      it "creates the directory and returns a new IsoRepo instance" do
        expect(FileUtils).to_not receive(:mkdir_p).with(directory)
        repo = described_class.init(directory)
        expect(repo).to be_kind_of(described_class)
        expect(repo.dir).to eq(directory)
      end
    end
  end

  describe "#get" do
    let(:iso_dir) { File.join(repo_dir, "dl.opensuse.org") }

    before do
      FileUtils.mkdir_p(iso_dir)
      FileUtils.touch(File.join(iso_dir, "build0001.iso"))
      FileUtils.mkdir_p(File.join(iso_dir, "empty"))
    end

    it "tries to download the ISO without overwriting any existing file" do
      expect(iso_repo).to receive(:system)
        .with(%r{wget .+no-clobber.+'leap-42.1.iso' http://dl.opensuse.org})
        .and_return(true)
      expect(iso_repo.get(iso_url)).to eq(File.join(iso_dir, "build0001.iso"))
    end

    context "when file could not be downloaded" do
      let(:exist?) { false }

      it "returns false" do
        expect(iso_repo).to receive(:system)
          .with(/wget/)
          .and_return(false)
        expect(iso_repo.get(iso_url)).to eq(false)
      end
    end
  end
end
