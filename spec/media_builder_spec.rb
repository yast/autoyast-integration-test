require "aytests"

RSpec.describe AYTests::MediaBuilder do
  let(:base_dir) { Pathname.new("/usr/local/aytests") }
  let(:work_dir) { Pathname.new("/home/autoyast/aytests") }
  let(:yast_url) { Pathname.new("http://build.suse.de/yast") }
  let(:iso_url) { Pathname.new("http://dl.suse.de/sles12.iso") }
  let(:dud_dist) { "sle12" }
  let(:dud_method) { "instsys,repo" }
  let(:version) { "sles12" }
  let(:output_path) { Pathname.pwd.join("spec/workspace/testing.iso") }

  subject(:builder) do
    AYTests::MediaBuilder.new(
      base_dir: base_dir, work_dir: work_dir, yast_url: yast_url,
      iso_url: iso_url, version: version, dud_dist: dud_dist,
      dud_method: dud_method
    )
  end

  describe "#build" do
    it "runs each building phase and returns true if build was successful" do
      expect(FileUtils).to receive(:rm_rf).with(builder.cache_dir)
      expect(FileUtils).to receive(:mkdir_p).with(output_path.dirname)
      expect(AYTests::IsoRepo).to receive(:get).with(iso_url)
      expect(subject).to receive(:fetch_obs_packages)
      expect(subject).to receive(:fetch_local_packages)
      expect(subject).to receive(:system).with(/mkdud/)
      expect(subject).to receive(:system).with(/sync/)
      expect(subject).to receive(:system).with(/mksusecd/).and_return(true)
      expect(subject.build(output_path)).to eq(true)
    end
  end

  describe "#cache_dir" do
    it "returns work_dir + 'cache'" do
      expect(subject.cache_dir).to eq(Pathname.new("#{work_dir}/cache"))
    end
  end

  describe "#local_packages_dir" do
    it "returns local_packages_dir + 'rpms/VERSION'" do
      expect(subject.local_packages_dir).to eq(Pathname.new("#{work_dir}/rpms/#{version}"))
    end
  end

  describe "#boot_path" do
    it "returns base_dir + share + boot_iso + boot_VERSION" do
      expect(subject.boot_dir).to eq(Pathname.new("#{base_dir}/share/build_iso/boot_#{version}"))
    end
  end

  describe "#obs_pkg_list_path" do
    it "returns base_dir + build_iso + VERSION.obs_packages" do
      expect(subject.obs_pkg_list_path)
        .to eq(Pathname.new("#{base_dir}/share/build_iso/#{version}.obs_packages"))
    end
  end

  describe "#cleanup" do
    it "cleans cache dir" do
      expect(FileUtils).to receive(:rm_rf).with(subject.cache_dir)
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
