# CLI
#
# This class implements the CLI.
require "yaml"
require "thor"

module AYTests
  class CLI < Thor
    desc "build_iso NAME", "Build boot image <name>"
    def build_iso(name)
      bootstrap
      config = YAML.load_file(base_dir.join("config", "definitions.yml")).fetch(name.to_sym)
      builder = AYTests::MediaBuilder.new(config.merge(base_dir: base_dir, version: name))
      builder.build
    end

    option "skip-build", type: :boolean
    desc "test FILE", "Run integration tests"
    def test(file = nil)
      bootstrap
      tests = file ? Array(file) :
        Dir.glob(AYTests.tests_path.join("*.rb")).reject { |f| File.basename(f) == "spec_helper.rb" }

      tests.sort.each do |test_file|
        if File.exist?(test_file)
          runner = AYTests::TestRunner.new(
            test_file: Pathname.new(test_file),
            default_iso_path: AYTests.obs_iso_path,
            skip_build: options["skip-build"] || false)
          runner.run
        else
          $stderr.puts "File #{test_file} does not exist"
        end
      end
    end

    desc "setup", "Set up the environment for the current user"
    def setup
      require "ay_tests/installer"
      config_file = base_dir.join("config", "setup.yml")
      installer = AYTests::Installer.new(YAML.load_file(config_file), ENV["LOGNAME"])
      installer.run
    end

    desc "clean", "Clean cache and kiwi state file"
    def clean
      FileUtils.rm_r(Dir["build_iso/cache", "kiwi/import_state.yaml"])
    end

    desc "clobber", "Remove ISO images, logs and Vagrant box file"
    def clobber
      FileUtils.rm_r(Dir["iso/*.iso", "kiwi/autoyast.box", "kiwi/iso/testing.iso", "log"])
    end

    private

    def bootstrap
      require "ay_tests"
      AYTests.base_dir = base_dir
      AYTests::IsoRepo.init(AYTests.base_dir.join("iso"))
    end

    def base_dir
      Pathname.new(File.dirname(__FILE__)).join("..", "..")
    end
  end
end
