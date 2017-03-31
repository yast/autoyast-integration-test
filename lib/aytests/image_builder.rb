require "uri"
require "socket"
require "aytests/vm"

module AYTests
  class ImageBuilder
    # Build a libvirt-kvm or a VirtualBox image using Veewee
    # https://github.com/jedi4ever/veewee

    include AYTests::Helpers

    attr_reader :sources_dir, :obs_iso_dir, :autoinst_path, :definition_path,
      :veewee_autoyast_dir, :libvirt_definition_path, :provider, :headless, :work_dir,
      :files_dir, :results_dir

    IMAGE_NAME = "autoyast"
    BACKUP_IMAGE_NAME = "autoyast_sav"
    ISO_FILE_NAME = "testing.iso"
    IMAGE_BOX_NAME = "autoyast_vagrant_box_image_0.img"
    SLEEP_TIME_AFTER_UPGRADE = 150
    SLEEP_TIME_AFTER_SHUTDOWN = 15
    SSH_USER = "vagrant"
    SSH_PASSWORD = "nots3cr3t"
    SSH_PORT = "22"
    WEBSERVER_PORT = "8888"
    MAC_ADDRESS = "02:00:00:12:34:56"
    POSTINSTALL_SCRIPT="/home/vagrant/postinstall.sh"
    DEFAULT_LINUXRC_ARGS = {
      "autoyast" => "http://%IP%:{{PORT}}/autoinst.xml"
    }
    CLONE_IMAGE_PATH = "/var/lib/libvirt/images/#{IMAGE_NAME}-1.qcow2"

    # Constructor
    #
    # @param [Pathname] sources_dir Set the directory where Veewee related
    #                               files live (templates for definition,
    #                               post-install script, etc.)
    # @param [Pathname] work_dir    Set the work directory. By default it
    #                               uses AYTests.work_dir
    # @param [Symbol]   provider    Provider to be used by Vagrant
    #                               (:libvirt or :virtualbox)
    # @param [Symbol]   headless    Disable GUI (only relevant for virtualbox
    #                               provider)
    def initialize(sources_dir: nil, work_dir: nil, results_dir: nil, files_dir: nil, provider: :libvirt, headless: false)
      @sources_dir = sources_dir
      @work_dir = work_dir
      @results_dir = results_dir
      @files_dir = files_dir
      @veewee_autoyast_dir = @work_dir.join("definitions", "autoyast")
      @obs_iso_dir = @work_dir.join("iso")
      @autoinst_path = @work_dir.join("definitions", "autoyast", "autoinst.xml")
      @definition_path = @work_dir.join("definitions", "autoyast", "definition.rb")
      # This file will be used by Veewee during upgrade.
      @libvirt_definition_path = @work_dir.join("definitions", "autoyast", "autoyast_description.xml")
      @headless = headless
      @provider = provider
    end

    # Due an aborted run there could be old stuff which should be
    # removed before starting a new run.
    #
    def cleanup_environment
      return unless provider == :libvirt
      pool_lines = Cheetah.run(["sudo", "virsh", "pool-list"], stdout: :capture).lines.drop(2)
      pools = pool_lines.collect { |l| l.split.first }.compact
      pools.each do |pool|
        vol_lines = Cheetah.run(["sudo", "virsh", "vol-list", pool], stdout: :capture).lines.drop(2)
        vol_lines.each do |v_string|
          name, pathname = v_string.split.compact
          if pathname
            regexp = Regexp.new("^#{IMAGE_NAME}-\\d+.qcow2")
            if !File.exist?(pathname) || name.match(regexp)
              # Either the file does not exists anymore or there are cloned instances
              # which have not been removed correctly by previous run.
              log.info "CLEANUP: Removing unneeded file #{pathname} in pool #{pool}"
              begin
                Cheetah.run(["sudo", "virsh", "vol-delete", pathname])
              rescue Cheetah::ExecutionFailed => e
                log.error e.message
                log.error e.stderr
                log.error "FAILED; please check manually"
              end
            end
          end
        end
      end
    end

    # Run the installation using a given profile and an ISO
    #
    # @param [Pathname]            autoinst Path to the AutoYaST profile to use.
    # @param [Pathname|URI|String] iso_url  URL/path to the ISO to use.
    # @return [Boolean] true if the system was successfully built; return false
    #   otherwise.
    #
    # @see iso_url
    # @see autoinst_path
    # @see setup_iso
    # @see setup_autoinst
    # @see setup_definition
    # @see build
    def install(autoinst, iso_url)
      prepare
      setup_iso(iso_url)
      setup_autoinst(autoinst)
      setup_definition(:install)
      ret = build(autoinst)
      download_logs(results_dir.join("installation-y2logs.tgz"))
      ret
    end

    # Run the installation using a given profile and an ISO
    #
    # @param [Pathname]            autoinst Path to the AutoYaST profile to use.
    # @param [Pathname|URI|String] iso_url  URL/path to the ISO to use.
    # @return [Boolean] true if the system was successfully built; return false
    #   otherwise.
    #
    # @see iso_url
    # @see autoinst_path
    # @see autoyast_description_path
    # @see setup_iso
    # @see setup_autoinst
    # @see setup_definition
    # @see change_boot_order
    # @see backup_image
    # @see build
    # @see run_postinstall
    def upgrade(autoinst, iso_url)
      prepare
      setup_iso(iso_url)
      setup_autoinst(autoinst)
      setup_definition(:upgrade)
      backup_image
      build(autoinst)
      # During upgrade, Veewee will fail because SSH is disabled by PAM during
      # booting. So Veewee will get a "Authentication Failure" and it will give
      # up. At this time, we'll wait some time so installation process can finish
      # properly. We should find a cleaner solution.
      log.info "Waiting #{SLEEP_TIME_AFTER_UPGRADE} seconds for upgrade process to finish"
      sleep SLEEP_TIME_AFTER_UPGRADE
      run_postinstall
      download_logs(results_dir.join("upgrade-y2logs.tgz"))
      true
    end

    # Import Veewee image into Vagrant
    #
    # @return [Boolean] true if the image was successfully imported; false
    #   otherwise.
    #
    # @see export_from_veewee
    def import
      export_from_veewee
      box_file = work_dir.join("#{IMAGE_NAME}.box")
      log.info "Importing #{veewee_provider} image into Vagrant"
      system "vagrant box add 'autoyast' #{box_file} --force"
    end

    # Export the created machine
    #
    # The machine will be exported to +kiwi/IMAGE_NAME.box+.
    #
    # @return [Boolean] true if the image was successfully exported; false
    #   otherwise.
    def export_from_veewee
      Dir.chdir(work_dir) do
        log.info "Exporting #{veewee_provider} image into box file"
        # veewee changes the owner of this file to root.
        # So the call "qemu-img convert" has no access anymore.
        # --> Access has to be set manually.
        if File.file? CLONE_IMAGE_PATH
          log.info "Giving write permissions to #{CLONE_IMAGE_PATH}"
          FileUtils.chmod( 0666, CLONE_IMAGE_PATH)
        end
        system "veewee #{veewee_provider} export #{IMAGE_NAME} --force"
      end
    end

    # Clean up used files
    #
    # Removes AutoYaST profile, Veewee definition and link to installation ISO
    def cleanup
      FileUtils.rm(autoinst_path, force: true)
      FileUtils.rm(definition_path, force: true)
      FileUtils.rm(libvirt_definition_path, force: true)
      if provider == :libvirt
        # Due a bug in vagrant-libvirt the images will not cleanuped correctly
        # in the /var/lib/libvirt directory. This has to be done manually
        # (including DB update)
        system "sudo virsh vol-delete #{IMAGE_BOX_NAME} default"
      end
    end

    # Veewee provider
    #
    # Translates Vagrant provider to Veewee.
    #
    # @return [Symbol] Veewee provider's name.
    def veewee_provider
      @veewee_provider =
        case @provider
        when :libvirt
          :kvm
        when :virtualbox
          :vbox
        else
          :unknown
        end
    end

    # Run post-install script in the virtual machine
    #
    # Veewee won't be able to run post-install script after upgrade.
    def run_postinstall
      log.info "Running post-install script"
      vm.run("sudo env #{POSTINSTALL_SCRIPT}", ssh_options)
    end

  private

    # Build a Vagrant image using Veewee
    #
    # @param  [Pathname] autoinst Path to AutoYaST profile
    # @return [Boolean] true if the system was successfully built; return false
    #   otherwise.
    def build(autoinst)
      Dir.chdir(work_dir) do
        log.info "Creating #{veewee_provider} image"
        cmd = "veewee #{veewee_provider} build #{IMAGE_NAME} --force --auto"
        cmd << " --nogui" if headless
        system(build_environment(autoinst), cmd)
      end
    end

    # Set up the ISO image
    #
    # It will link the ISO image through a link called +ISO_FILE_NAME+.
    # The directory where this link will live is determined through
    # the #obs_iso_dir method.
    #
    # It rely on AYTests::IsoRepo class so local and remote locations
    # are supported.
    #
    # @see obs_iso_dir
    def setup_iso(iso_url)
      iso_path = URI(iso_url.to_s).host ? IsoRepo.get(iso_url) : iso_url
      FileUtils.rm(obs_iso_dir.join(ISO_FILE_NAME), force: true)
      FileUtils.ln_s(iso_path, obs_iso_dir.join(ISO_FILE_NAME))
    end

    # Set up the definition
    #
    # It copies the Veewee definition depending on the mode. Definitions
    # will live in #sources_dir directory, usually `share/veewee`.
    #
    # @param [String|Symbol] mode :install for installation or :upgrade for upgrade.
    def setup_definition(mode)
      source_definition = sources_dir.join("#{mode}_definition.rb")
      log.info "Using definition #{source_definition}"
      FileUtils.cp(source_definition, definition_path)
    end

    # Set up AutoYaST profile
    #
    # It copies the AutoYaST profile so Veewee can use it.
    #
    # @param [String|Pathname] autoinst AutoYaST profile path.
    def setup_autoinst(autoinst)
      if autoinst.file?
        content = File.read(autoinst)
        autoinst_vars(autoinst.sub_ext(".vars")).each { |k, v| content.gsub!("{{#{k}}}", v) }
        content.gsub!("/dev/vd", "/dev/sd") if provider == :virtualbox
        File.open(autoinst_path, "w") { |f| f.puts content }
      else
        log.info "No profile found. No problem, it should be available at /static"
      end
    end

    # Change boot order for libvirt definition
    #
    # It will use a temporal file that won't be deleted (as it will
    # be needed by Veewee's upgrade definition).
    #
    # @params [Pathname,String] definition Path to the libvirt domain definition
    #   for the KVM image.
    def change_boot_order
      return unless provider == :libvirt
      system "sudo virsh destroy #{IMAGE_NAME}" # shutdown
      system "sudo virsh dumpxml #{IMAGE_NAME} >#{libvirt_definition_path}"
      system "sed -i.bak s/dev=\\'cdrom\\'/dev=\\'cdrom_save\\'/g #{libvirt_definition_path}"
      system "sed -i.bak s/dev=\\'hd\\'/dev=\\'cdrom\\'/g #{libvirt_definition_path}"
      system "sed -i.bak s/dev=\\'cdrom_save\\'/dev=\\'hd\\'/g #{libvirt_definition_path}"
      system "sudo virsh define #{libvirt_definition_path}"
    end

    # Backup image
    #
    # The image will be destroyed by Veewee when starting the upgrade. So we need to
    # backup it and restore in Veewee's +after_create+ hook. Note: doing this in the
    # +before_create+ hook won't work as the machine is destroyed previously.
    def backup_image
      vm.backup(BACKUP_IMAGE_NAME)
    end

    # Determine the host IP
    #
    # @return [String] Host IP address.
    #
    # Taken from Veewee to make sure that the IP matches.
    def local_ip
      return @local_ip if @local_ip
      # turn off reverse DNS resolution temporarily
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true

      UDPSocket.open do |s|
        s.connect '64.233.187.99', 1 # google
        @local_ip = s.addr.last
      end
    ensure
      Socket.do_not_reverse_lookup = orig
    end

    # Prepare Veewee directory
    #
    # Create Veewee directory and copy post install script.
    def prepare
      FileUtils.mkdir_p(veewee_autoyast_dir) unless veewee_autoyast_dir.directory?
      FileUtils.cp(sources_dir.join("postinstall.sh"), veewee_autoyast_dir)
    end

    # Build an environment for Veewee
    #
    # Set some environment variables:
    #
    # * AYTESTS_BACKUP_IMAGE_NAME: image name for virtual machine's backup.
    # * AYTESTS_FILES_DIR: files to be served through HTTP.
    # * AYTESTS_SOURCES_DIR: directory where Veewee related files live.
    # * AYTESTS_RESULTS_DIR: directory to save results (logs, screenshots, etc.)
    # * AYTESTS_IMAGE_NAME: image name for the virtual machine's disk.
    # * AYTESTS_IP_ADDRESS: local IP.
    # * AYTESTS_MAC_ADDRESS: MAC address.
    # * AYTESTS_WEBSERVER_PORT: files webserver port (WEBSERVER_PORT).
    # * AYTESTS_PROVIDER: virtual machine's provider (virtualbox or libvirt).
    # * AYTESTS_LINUXRC: additional parameters for Linuxrc. They're taken
    #   from a file called after the profile but with `.linuxrc` extension.
    #
    # @param  [Pathname] autoinst Path to AutoYaST profile
    # @return [Hash] Variables to be used as environment for Veewee
    def build_environment(autoinst)
      environment = {
        "AYTESTS_BACKUP_IMAGE_NAME" => BACKUP_IMAGE_NAME,
        "AYTESTS_FILES_DIR" => files_dir.to_s,
        "AYTESTS_SOURCES_DIR" => sources_dir.to_s,
        "AYTESTS_RESULTS_DIR" => results_dir.to_s,
        "AYTESTS_IMAGE_NAME" => IMAGE_NAME,
        "AYTESTS_IP_ADDRESS" => local_ip,
        "AYTESTS_MAC_ADDRESS" => MAC_ADDRESS,
        "AYTESTS_PROVIDER" => provider.to_s,
        "AYTESTS_WEBSERVER_PORT" => WEBSERVER_PORT
      }
      environment["AYTESTS_LINUXRC"] = linuxrc_options(autoinst.sub_ext(".linuxrc"))
      environment
    end

    # Build a variables hash to be replaced in the profile
    #
    # The following placeholders can be used:
    #
    # * {{IP}} will be replaced for #local_ip value.
    # * {{PORT}} will be replaced for WEBSERVER_PORT
    #
    # @param [Pathname] vars_file File containing variables definitions.
    # @return [Hash] Variables to be replace placeholders in the profile
    #
    # @see #local_ip
    def autoinst_vars(vars_file)
      return {} unless vars_file.exist?
      content = File.read(vars_file).
        gsub("{{IP}}", local_ip).
        gsub("{{PORT}}", WEBSERVER_PORT)
      content.split("\n").reduce({}) do |hsh, line|
        key, value = line.split("=")
        hsh[key] = value
        hsh
      end
    end

    # Build arguments for Linuxrc
    #
    # * Read arguments from .linuxrc file.
    # * Merge arguments with default ones.
    # * Replaces {{PORT}} for WEBSERVER_PORT variable.
    #
    # @param  [Pathname] linuxrc_file Path to Linuxrc options file
    # @return [String]   Linuxrc options to be used during installation
    def linuxrc_options(linuxrc_file)
      options = DEFAULT_LINUXRC_ARGS.merge(custom_linuxrc_options(linuxrc_file))
      options_string = linuxrc_options_to_s(options)
      options_string.gsub(/{{\w+}}/, "{{PORT}}" => WEBSERVER_PORT)
    end

    # Retrieve Linuxrc options from the given file
    #
    # @param  [Pathname] linuxrc_file Path to Linuxrc options file
    # @return [Hash]     Linuxrc options
    def custom_linuxrc_options(linuxrc_file)
      if linuxrc_file.file?
        content = File.read(linuxrc_file).chomp
        content.split.each_with_object({}) do |o, opts|
          key, val = o.split("=")
          opts[key] = val
        end
      else
        {}
      end
    end

    # Convert a hash contaning Linuxrc options to a string
    #
    # @param  [Hash]   options Linuxrc options
    # @return [String] Linuxrc options to be used during installation
    def linuxrc_options_to_s(options)
      parts = options.map do |key, val|
        val.nil? ? key : "#{key}=#{val}"
      end
      parts.join(" ")
    end

    # Download YaST2 logs from the virtual machine
    #
    # @param [Pathname] path File to save the logs
    # @return [Boolean] True if the download was successful; false otherwise.
    def download_logs(path)
      log.info "Downloading YaST2 logs"
      # save_y2logs is not always available (CaaSP or mininal installation)
      vm.run("sudo /bin/tar -C /var/log -czf /tmp/logs.tgz YaST2", ssh_options)
      vm.download("/tmp/logs.tgz", path, ssh_options)
    end

    # Return a representation of the virtual machine
    #
    # This class provides methods to run code, download logs, etc.
    #
    # @return [AYTests::VM] Virtual machine
    def vm
      @vm ||= VM.new(IMAGE_NAME, provider)
    end

    def ssh_options
      @ssh_options ||= {
        user:     SSH_USER,
        password: SSH_PASSWORD,
        port:     SSH_PORT
      }
    end
  end
end
