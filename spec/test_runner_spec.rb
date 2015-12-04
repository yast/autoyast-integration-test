require "spec_helper"
require "aytests/test_runner"

RSpec.describe AYTests::TestRunner do
  DEFAULT_ISO_PATH = TEST_WORK_DIR.join("iso", "obs.iso")
  let(:test_file) { Pathname.new(__FILE__).dirname.join("files", "sles12.rb") }
  let(:skip_build) { false }

  subject(:runner) do
    AYTests::TestRunner.new(
      work_dir: TEST_WORK_DIR,
      test_file: test_file,
      default_iso_path: DEFAULT_ISO_PATH,
      skip_build: skip_build)
  end

  describe "#run" do
    let(:builder) { double("builder") }

    before(:each) do
      allow(AYTests::ImageBuilder).to receive(:new).and_return(builder)
      FileUtils.mkdir_p(TEST_WORK_DIR)
    end

    context "with default configuration" do
      it "builds a new VM and returns test results" do
        expect(builder).to receive(:install)
        expect(runner).to receive(:system)
          .with({"AYTESTS_WORK_DIR" => TEST_WORK_DIR.to_s},
                "rspec #{test_file.basename}").and_return(true)
        expect(builder).to receive(:import)
        expect(builder).to receive(:cleanup)
        expect(runner.run).to eq(true)
      end
    end

    context "when test fail" do
      it "returns false" do
        expect(builder).to receive(:install)
        expect(runner).to receive(:system)
          .with({"AYTESTS_WORK_DIR" => TEST_WORK_DIR.to_s},
                "rspec #{test_file.basename}").and_return(false)
        expect(builder).to receive(:import)
        expect(builder).to receive(:cleanup)
        expect(runner.run).to eq(false)
      end
    end

    context "when upgrade is requested" do
      let(:test_file) { Pathname.new(__FILE__).dirname.join("files", "upgrade_sles12.rb") }

      it "builds a new VM running also the upgrade stage and returns tests results" do
        expect(builder).to receive(:install)
        expect(builder).to receive(:upgrade)
        expect(runner).to receive(:system)
          .with({"AYTESTS_WORK_DIR" => TEST_WORK_DIR.to_s},
                "rspec #{test_file.basename}").and_return(true)
        expect(builder).to receive(:import)
        expect(builder).to receive(:cleanup)
        expect(runner.run).to eq(true)
      end
    end

    context "when build is disabled" do
      let(:skip_build) { true }

      it "does not create a VM and returns tests results" do
        expect(AYTests::ImageBuilder).to_not receive(:new)
        expect(runner).to receive(:system)
          .with({"AYTESTS_WORK_DIR" => TEST_WORK_DIR.to_s},
                "rspec #{test_file.basename}").and_return(true)
        expect(runner.run).to eq(true)
      end
    end
  end
end
