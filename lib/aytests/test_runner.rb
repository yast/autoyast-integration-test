require "fileutils"

module AYTests
  # This class is responsible for building a virtual machine
  # and running the tests.
  #
  # @see AYTests::ImageBuilder
  class TestRunner
    include AYTests::Helpers

    attr_reader :test_name, :files_dir, :test_file, :work_dir,
      :default_iso_path, :skip_build, :provider, :headless,
      :results_dir

    # Constructor
    #
    # @param [String] test_file        Path to tests file
    # @param [String] work_dir         Work directory
    # @param [String] default_iso_path Path to the default ISO (can be overriden through
    #                                  *.{install,upgrade}_iso files)
    # @param [True,False] skip_build   Do not build the virtual machine
    # @param [String|Symbol] provider  Set the vagrant provider (:libvirt or :virtualbox)
    # @param [True,False] headless     Enable headless mode if true
    def initialize(test_file:, work_dir:, default_iso_path:, skip_build: false, provider: :libvirt, headless: false)
      @test_file        = Pathname.new(test_file).expand_path
      @default_iso_path = default_iso_path
      @skip_build       = skip_build
      @test_name        = @test_file.basename(".rb")
      @files_dir        = @test_file.dirname.join("files")
      @work_dir         = work_dir
      @provider         = provider.to_sym
      @headless         = headless
      @results_dir      = work_dir.join("results", Time.now.strftime("%Y%m%d%H%M"))
    end

    # Build a virtual machine and run the tests on it
    #
    # @return [Boolean] `true` if tests were successful; `false` otherwise
    #
    # @see #build
    def run
      log.info "Running test #{test_name}"
      unless skip_build
        setup_results_dir
        build
      end
      Dir.chdir(test_file.dirname) do
        system(
          { "AYTESTS_WORK_DIR" => work_dir.to_s, "AYTESTS_PROVIDER" => provider.to_s },
          "rspec #{test_file.basename}"
        )
      end
    end

  private

    # Build a virtual machine to build the tests
    #
    # @see AYTests::ImageBuilder
    def build
      builder = AYTests::ImageBuilder.new(
        sources_dir: AYTests.base_dir.join("share", "veewee"),
        work_dir:    work_dir,
        files_dir:   files_dir,
        results_dir: results_dir,
        provider:    provider,
        headless:    headless
      )
      builder.cleanup_environment
      builder.install(autoinst(:install), iso_url(:install))
      builder.upgrade(autoinst(:upgrade), iso_url(:upgrade)) if upgrade?
      builder.import
      builder.cleanup
    end

    # Determine AutoYaST profile path
    #
    # @param [String] stage :install or :upgrade stage
    # @return [String]      AutoYaST profile path for the given stage
    def autoinst(stage = :install)
      autoinst = tests_path.join("#{test_name}.#{stage}_xml")
      autoinst.file? ? autoinst : tests_path.join("#{test_name}.xml")
    end

    # Determine ISO url to be used
    #
    # @param [String] stage :install or :upgrade stage
    # @return [String]      ISO URL for the given stage
    def iso_url(stage = :install)
      iso_path_file = tests_path.join("#{test_name}.#{stage}_iso")
      File.file?(iso_path_file) ? IO.binread(iso_path_file).chomp : default_iso_path
    end

    # Determine whether the upgrade should be done
    #
    # It relies on #test_name to determine whether the upgrade is needed
    # (if name starts with "upgrade_", then it's needed).
    #
    # @return [Boolean] `true` if the upgrade should be performed. Otherwise, `false`.
    def upgrade?
      test_name.to_s.start_with?("upgrade_")
    end

    # Find tests path
    #
    # Returns the directory of the test_file.
    #
    # @return [Pathname] Tests path
    def tests_path
      test_file.dirname
    end

    # Set up the results directory
    #
    # Create the results directory and link it as the "latest"
    def setup_results_dir
      FileUtils.mkdir_p(results_dir) unless results_dir.exist?
      latest_link = results_dir.parent.join("latest")
      FileUtils.rm_f(latest_link)
      FileUtils.ln_sf(results_dir, latest_link)
    end
  end
end
