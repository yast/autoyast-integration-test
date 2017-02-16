module AYTests
  # Builds an ISO to be used during integration tests
  #
  # This builder will perform the following steps to build a new ISO:
  #
  # * Downloads a base ISO
  # * Grabs packages from OBS to be included in the new ISO
  # * Grabs user packages from a given directory
  # * Builds a DUD using updated packages and finally builds the final ISO
  class MediaBuilder
    include AYTests::Helpers

    attr_reader :base_dir, :cache_dir, :local_packages_dir, :boot_dir,
      :iso_path, :obs_pkg_list_path, :yast_url, :iso_url, :version, :output_path,
      :dud_dist, :dud_method

    # --prefix=37 sets a directory prefix to avoid conflicts. Check mkdud README.
    MKDUD_CMD = "mkdud -c %<dud_path>s -d %<dud_dist>s -i  %<dud_method>s --prefix=37 " \
      "--format=tar.gz $(find %<rpms_dir>s -name \"\*\.rpm\") %<dud_dir>s"
    MKSUSECD_CMD = "sudo mksusecd -c %<output_path>s --initrd=%<dud_path>s %<iso_path>s"

    # Constructor
    #
    # @param [Pathname] base_dir Set the base directory. By default it uses
    #   AYTests.base_dir.
    # @param [String,Array<String>] yast_url YaST repositories URL
    # @param [Pathname] iso_url  Base ISO URL
    # @param [String]   version  Distribution version (+sles12+, +sles12-sp1+, etc.)
    # @param [String]   dud_dist Distribution type for +mkdud+ (+sle12+, +caasp1.0+, etc.)
    # @param [String]   dud_method Driver update disk mode (see +method+ option in +mkdud+)
    # @param [Pathname] work_dir Working directory. By default it uses AYTests.work_dir.
    # @param [Array<Hash>] extra_repos Extra repositories and packages to add to the
    #   ISO. The information for each repository consists in a Hash with +:server+
    #   and a +:packages+ keys.
    def initialize(yast_url:, iso_url:, version:, dud_dist:, dud_method: nil, base_dir: nil, work_dir: nil, extra_repos: [])
      # Directories
      @base_dir           = base_dir || AYTests.base_dir
      @work_dir           = work_dir || AYTests.work_dir
      @cache_dir          = @work_dir.join("cache")
      @local_packages_dir = @work_dir.join("rpms", version)
      @obs_pkg_list_path  = @base_dir.join("share", "build_iso", "#{version}.obs_packages")
      @boot_dir           = @base_dir.join("share", "build_iso", "boot_#{version}")

      # URLs
      @yast_url = Array(yast_url)
      @iso_url  = iso_url

      # Misc data
      @version     = version
      @extra_repos = extra_repos || []
      @dud_dist    = dud_dist
      @dud_method  = dud_method || "instsys,repo"
    end

    # Build a new ISO using packages from OBS
    #
    # * Do some cleanup
    # * Download the original ISO (relying on AYTests::IsoRepo)
    # * Fetch required packages
    # * Fetch local packages
    # * Create the final ISO
    #
    # @return [Boolean] true if image was successfully built; otherwise
    #   return false.
    #
    # @see cleanup
    # @see download_iso
    # @see fetch_obs_packages
    # @see fetch_local_packages
    # @see build_iso
    def build(output_path = nil)
      cleanup
      iso_path = download_iso
      fetch_obs_packages
      fetch_local_packages
      build_iso(iso_path, output_path || AYTests.obs_iso_path)
    end

    # Clean-up cache directory
    def cleanup
      log.info("Cleaning up #{cache_dir}")
      FileUtils.rm_rf(cache_dir)
    end

    # Download the base ISO
    #
    # It relies on IsoRepo which will take care of downloading the
    # ISO when it's needed.
    #
    # @return [Pathname] Path to downloaded ISO.
    #
    # @see AYTests::IsoRepo.get
    def download_iso
      IsoRepo.get(iso_url)
    end

    # Fetch OBS packages
    #
    # Method #obs_pkg_list_path will point to the list of packages to be
    # downloaded. If @extra_repos contains a list of repositories and packages,
    # it will download those packages as well.
    def fetch_obs_packages
      log.info "Fetching all required packages"
      yast_url.each_with_index do |url, index|
        system "zypper --root #{cache_dir} ar --no-gpgcheck -p #{index+1} #{url} download-packages-#{index}"
      end
      system "xargs -a #{obs_pkg_list_path} zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download"

      yast_url.size.times { |i| system "zypper --root #{cache_dir} rr download-packages-#{i}" }

      log.info "Fetching packages from extra repositories"
      @extra_repos.each do |repo|
        system "zypper --root #{cache_dir} ar --no-gpgcheck #{repo[:server]} download-extra-packages"
        system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download #{repo[:packages].join(" ")}"
        system "zypper --root #{cache_dir} rr download-extra-packages"
      end
    end

    # Fetch local packages
    #
    # Get local packages from `rpms/VERSION` (e.g. `rpms/sle12`) directory.
    def fetch_local_packages
      Dir[@local_packages_dir.join("*.rpm").to_s].each do |package|
        # Replace downloaded packages for local ones
        rpm_name = `rpm -qp --qf \"%{NAME}\" #{package}`
        Dir[cache_dir.join("**", "*.rpm").to_s].each do |rpm_to_exchange|
          if `rpm -qp --qf \"%{NAME}\" #{rpm_to_exchange}` == rpm_name
            log.info "Removing #{rpm_to_exchange}"
            FileUtils.remove_file(rpm_to_exchange)
          end
        end
        log.info "Copying #{package}"
        FileUtils.cp(package, cache_dir)
      end
    end

    # Build the final ISO
    #
    # A new ISO is built including:
    #
    # * A DUD containing all the OBS packages and the content
    #   of directory +build_iso/dud+.
    # * A boot directory (if +boot_VERSION+ directory exists).
    # * The original ISO:
    #
    # @return [Boolean] true if image was successfully built; otherwise
    #   return false.
    def build_iso(iso_path, output_path)
      log.info "Creating DUD"
      dud_path = cache_dir.join("#{version}.dud")
      dud_dir = base_dir.join("share", "build_iso", "dud", version)
      # Must have root access
      system("sudo mkdir -p #{dud_dir}") unless File.directory?(dud_dir)

      cmd = format(MKDUD_CMD, dud_path: dud_path, dud_dist: dud_dist,
        dud_method: dud_method, dud_dir: dud_dir, rpms_dir: cache_dir)
      log.info "Command: #{cmd}"
      system cmd

      log.info "Syncing to disk"
      system "sync"

      log.info "Creating new ISO image with the updated packages"
      FileUtils.mkdir_p(output_path.dirname) unless output_path.dirname.directory?
      cmd = format(MKSUSECD_CMD, output_path: output_path, dud_path: dud_path,
                   iso_path: iso_path)
      cmd << " #{boot_dir}" if boot_dir.directory?
      log.info "Command: #{cmd}"
      system cmd
    end
  end
end
