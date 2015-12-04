module AYTests
  # This class is responsible for building a virtual machine
  # and running the tests.
  #
  # @see AYTests::ImageBuilder
  class TestRunner
    include AYTests::Helpers

    attr_reader :test_name, :test_file, :skip_build, :default_iso_path,
      :files_dir, :work_dir

    # Constructor
    #
    # @param [String] test_file Path to tests file
    def initialize(test_file:, work_dir:, default_iso_path:, skip_build: false)
      @test_file        = Pathname.new(test_file)
      @default_iso_path = default_iso_path
      @skip_build       = skip_build
      @test_name        = @test_file.basename(".rb")
      @files_dir        = File.join(File.dirname(@test_file), "files")
      @work_dir         = work_dir
    end

    # Build a virtual machine and run the tests on it
    #
    # @return [Boolean] `true` if tests were successful; `false` otherwise
    #
    # @see #build
    def run
      log.info "Running test #{test_name}"
      build unless skip_build
      Dir.chdir(test_file.dirname) do
        system({ "AYTESTS_WORK_DIR" => work_dir.to_s }, "rspec #{test_file.basename}")
      end
    end

    private

    # Build a virtual machine to build the tests
    #
    # @see AYTests::ImageBuilder
    def build
      builder = AYTests::ImageBuilder.new(
        sources_dir: AYTests.base_dir.join("share", "veewee"),
        files_dir: files_dir,
        provider: AYTests.provider,
        gui: ENV["AYTESTS_HEADLESS"] != "true")
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
      iso_url = File.file?(iso_path_file) ? IO.binread(iso_path_file).chomp : default_iso_path
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

  end
end
