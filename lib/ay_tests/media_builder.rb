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

    attr_reader :base_dir, :cache_dir, :local_packages_dir,
      :local_packages_dir, :boot_dir, :iso_path, :obs_pkg_list_path, :yast_url,
      :iso_url, :version

    # Constructor
    #
    # @params [Pathname] base_dir Set the base directory. By default it uses
    #   AYTests.base_dir.
    # @params [Pathname] yast_url YaST repository URL
    # @params [Pathname] iso_url  Base ISO URL
    # @params [String]   version  Distribution version (+sle12+, +sle12_sp1+, etc.)
    def initialize(yast_url:, iso_url:, version:, base_dir: nil)
      # Directories
      @base_dir           = base_dir || AYTests.base_dir
      @cache_dir          = base_dir.join("cache")
      @local_packages_dir = base_dir.join("rpms", version)
      @boot_dir           = base_dir.join("boot_#{version}")
      @obs_pkg_list_path  = base_dir.join("build_iso", "#{version}.obs_packages")

      # URLs
      @yast_url = yast_url
      @iso_url  = iso_url

      # Misc data
      @version = version
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
      FileUtils.rm_r(cache_dir)
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
    # Method #obs_pkg_list_path will point to the list of packages to be downloaded.
    # Moreover, some extra packages are downloaded (grub2, libzypp, libsolv-tools and zypper).
    def fetch_obs_packages
      puts "\n**** Fetching all required packages ****"
      system "zypper --root #{cache_dir} ar --no-gpgcheck #{yast_url} download-packages"
      system "xargs -a #{obs_pkg_list_path} zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download"

      puts "\n**** Fetching latest grub2 and libzypp packages ****"
      system "zypper --root #{cache_dir} rr download-packages"
      system "zypper --root #{cache_dir} ar --no-gpgcheck http://download.suse.de/ibs/SUSE:/SLE-12-SP1:/GA/standard/ download-packages"
      system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download grub2-2.02~beta2"
      system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download grub2-i386-pc-2.02~beta2"
      system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download libzypp"
      system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download libsolv-tools"
      system "zypper --root #{cache_dir} --pkg-cache-dir=#{cache_dir} download zypper"
    end

    # Fetch local packages
    #
    # Get local packages from `rpms/VERSION` (e.g. `rpms/sle12`) directory.
    def fetch_local_packages
      Dir[@local_packages_dir.join("*.rpm").to_s].each do |package|
        # Replace downloaded packages for local ones
        rpm_name = `rpm -qp --qf \"%{NAME}\" #{package}`
        Dir[cache_dir.join("**", "*.rpm").to_s].each do |remote|
          if `rpm -qp --qf \"%{NAME}\" #{exchange_rpm}` == rpm_name
            log.info "Removing #{remote}"
            FileUtils.remove_file(remote)
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
      dud_dir = base_dir.join("build_iso", "dud")
      system "mkdud -c #{dud_path} -d sle12 -i  instsys,repo --prefix=37 --format=tar.gz $(find -name \"\*\.rpm\") #{dud_dir}"

      log.info "Syncing to disk"
      system "sync"

      log.info "Creating new ISO image with the updated packages"
      cmd = "sudo mksusecd -c #{output_path} --initrd=#{dud_path} #{iso_path}"
      cmd << " #{boot_dir}" if boot_dir.directory?
      system cmd
    end
  end
end
