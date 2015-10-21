require "spec_helper"
require "ay_tests/iso_repo"

RSpec.describe AYTests::IsoRepo do
  let(:iso_dir) { Pathname.new("/tmp") }
  let(:iso_url) { "http://dl.opensuse.org/leap-42.1.iso" }

  subject(:iso_repo) { AYTests::IsoRepo.new(iso_dir) }

  describe "#get" do
    let(:iso_path) { double("iso_dir", exist?: exist?) }

    before do
      allow(iso_dir).to receive(:join).and_return(iso_path)
    end

    context "when file exists" do
      let(:exist?) { true }
      let(:iso_path) { double("iso_dir", exist?: true) }

      it "does not download anything and returns the path" do
        expect(iso_repo).to_not receive(:download_to)
        expect(iso_repo.get(iso_url)).to eq(iso_path)
      end
    end

    context "when file does not exist" do
      let(:exist?) { false }

      it "downloads the file and returns the path" do
        expect(iso_repo).to receive(:download_to)
          .with(iso_url, iso_path).and_return(true)
        expect(iso_repo.get(iso_url)).to eq(iso_path)
      end
    end

    context "when file does not exist and could not be downloaded" do
      let(:exist?) { false }

      it "returns false" do
        allow(iso_repo).to receive(:download_to)
          .with(iso_url, iso_path).and_return(false)
        expect(iso_repo.get(iso_url)).to eq(false)
      end
    end
  end
end
