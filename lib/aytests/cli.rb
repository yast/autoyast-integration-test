# CLI
#
# This class implements the CLI.
require "yaml"
require "thor"
require "pathname"
require "aytests"
require "aytests/installer"

module AYTests
  # CLI interface
  #
  # It uses Thor to handle command line options
  class CLI < Thor
    TEST_PASSED_ERRCODE = 0
    TEST_DOES_NOT_EXIST_ERRCODE = 1
    TEST_FAILED_ERRCODE = 2

    TESTS_COLORS = {
      failed:  :red,
      missing: :yellow,
      passed:  :green
    }.freeze

    option "work-dir", type: :string
    desc "build_iso NAME", "Build boot image <name>"
    def build_iso(name)
      bootstrap(options["work-dir"])
      config = YAML.load_file(base_dir.join("config", "definitions.yml")).fetch(name.to_sym)
      builder = AYTests::MediaBuilder.new(config.merge(base_dir: base_dir, version: name))
      builder.build
    end

    option "headless", type: :boolean
    option "provider", type: :string
    option "skip-build", type: :boolean
    option "work-dir", type: :string
    desc "test FILES", "Run integration tests"
    def test(*files)
      bootstrap(options["work-dir"])
      if files.empty?
        help("test")
        exit TEST_DOES_NOT_EXIST_ERRCODE
      end
      results = files.each_with_object({}) do |test_file, hsh|
        hsh[test_file] = test_result(test_file)
      end
      tests_again = results.select {|file,ret| ret == :failed }.keys
      unless tests_again.empty?
        say "giving following tests an additional try:"
        say tests_again
        tests_again.each do |test_file|
          results[test_file] = test_result(test_file)
        end
      end
      show_results(results)
      status = results.values.all? { |r| r == :passed } ? TEST_PASSED_ERRCODE : TEST_FAILED_ERRCODE
      exit(status)
    end

    desc "setup", "Set up the environment for the current user"
    def setup
      config_file = base_dir.join("config", "setup.yml")
      installer = AYTests::Installer.new(YAML.load_file(config_file), ENV["LOGNAME"])
      installer.run
    end

    option "work-dir", type: :string
    desc "clean", "Clean cache and Veewee files"
    def clean
      bootstrap(options["work-dir"])
      FileUtils.rm_rf([work_dir.join("cache"), work_dir.join("veewee")])
    end

  private

    # Initialize AYTests
    #
    # @param [String|Pathname] work_dir Work directory ($HOME/aytests-workspace
    #                                   by default)
    def bootstrap(work_dir = nil)
      AYTests.init(work_dir || Pathname.new(ENV["HOME"]).join("aytests-workspace"))
      AYTests::IsoRepo.init(AYTests.work_dir.join("iso"))
    end

    # Return the AYTests base directory
    #
    # Just for convenience.
    def base_dir
      AYTests.base_dir
    end

    # Return the AYTests work directory
    #
    # Just for convenience.
    def work_dir
      AYTests.work_dir
    end

    # Print tests results
    def show_results(results)
      say "Tests results:"
      results.each do |test, result|
        say_status result, test, TESTS_COLORS[result]
      end
    end

    # Run a test a return the result
    #
    # @param test_file [String] Path to the test to run
    # @return [:passed,:missing,:failed] :passed if test passed, :missing if
    #   test_file does not exist and :failed if test failed.
    def test_result(test_file)
      return :missing unless File.exist?(test_file)
      runner = AYTests::TestRunner.new(runner_options(test_file))
      # When a test fails, a non-zero return code will be returned
      runner.run ? :passed : :failed
    end

    # options to pass to the runner
    def runner_options(test_file)
      {
        work_dir:         AYTests.work_dir,
        test_file:        Pathname.new(test_file),
        default_iso_path: AYTests.obs_iso_path,
        skip_build:       options["skip-build"] || false,
        provider:         options["provider"] || ENV["AYTESTS_PROVIDER"] || :libvirt,
        headless:         options[:headless] || ENV["AYTESTS_HEADLESS"] == "true"
      }
    end
  end
end
