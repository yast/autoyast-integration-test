# CLI
#
# This class implements the CLI.
require "yaml"
require "thor"
require "pathname"
require "aytests"
require "aytests/installer"

module AYTests
  class CLI < Thor
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
        exit 1
      end

      files.each do |test_file|
        if File.exist?(test_file)
          runner = AYTests::TestRunner.new(
            work_dir: AYTests.work_dir,
            test_file: Pathname.new(test_file),
            default_iso_path: AYTests.obs_iso_path,
            skip_build: options["skip-build"] || false,
            provider: options["provider"] || ENV["AYTESTS_PROVIDER"] || :libvirt,
            headless: options[:headless] || ENV["AYTESTS_HEADLESS"] == "true"
          )
          runner.run
        else
          $stderr.puts "File #{test_file} does not exist"
        end
      end
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
  end
end
