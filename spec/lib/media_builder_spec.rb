require "ay_tests/media_builder"
require "pathname"

RSpec.describe AYTests::MediaBuilder do
  let(:base_dir) { Pathname.new("/home/autoyast") }
  let(:yast_url) { Pathname.new("http://build.suse.de/yast") }
  let(:iso_url) { Pathname.new("http://dl.suse.de/sles12.iso") }
  let(:version) { "sle12" }

  subject(:builder) do
    AYTests::MediaBuilder.new(
      base_dir: base_dir, yast_url: yast_url, iso_url: iso_url, version: version)
  end

  describe "#run" do
    it "runs each building phase and returns output path" do
      expect(subject).to receive(:cleanup)
      expect(subject).to receive(:download_iso)
      expect(subject).to receive(:fetch_obs_packages)
      expect(subject).to receive(:fetch_local_packages)
      expect(subject).to receive(:build_iso)
      expect(subject).to receive(:output_path).and_return("/home/autoyast/output")
      expect(subject.run).to eq("/home/autoyast/output")
    end
  end

  describe "#cache_dir" do
    it "returns base_dir + 'cache'" do
      expect(subject.cache_dir).to eq(Pathname.new("#{base_dir}/cache"))
    end
  end

  describe "#iso_dir" do
    it "returns base_dir + 'iso'" do
      expect(subject.iso_dir).to eq(Pathname.new("#{base_dir}/iso"))
    end
  end

  describe "#local_packages_dir" do
    it "returns local_packages_dir + 'rpms/VERSION'" do
      expect(subject.local_packages_dir).to eq(Pathname.new("#{base_dir}/rpms/#{version}"))
    end
  end

  describe "#boot_path" do
    it "returns cache_dir + boot_VERSION" do
      expect(subject.boot_dir).to eq(Pathname.new("#{base_dir}/boot_#{version}"))
    end
  end

  describe "#iso_path" do
    it "returns iso_dir + ISO basename (eg. sles12.iso)" do
      expect(subject.iso_path).to eq(Pathname.new("#{base_dir}/iso/sles12.iso"))
    end
  end

  describe "#obs_pkg_list_path" do
    it "returns base_dir + build_iso + VERSION.obs_packages" do
      expect(subject.obs_pkg_list_path)
        .to eq(Pathname.new("#{base_dir}/build_iso/#{version}.obs_packages"))
    end
  end

  describe "#cleanup" do
    it "cleans cache dir" do
      expect(FileUtils).to receive(:rm_r).with(subject.cache_dir)
      subject.cleanup
    end
  end

  describe "#download_iso" do
    context "the ISO is retrieved successfully" do
      let(:iso_path) { Pathname.new("my.iso") }

      it "returns the path to the downloaded ISO" do
        expect(AYTests::IsoRepo).to receive(:get).with(Pathname).and_return(iso_path)
        expect(subject.download_iso).to eq(iso_path)
      end
    end

    context "the ISO can't be retrieved" do
      it "returns false" do
        expect(AYTests::IsoRepo).to receive(:get).with(Pathname).and_return(false)
        expect(subject.download_iso).to eq(false)
      end
    end
  end
end
