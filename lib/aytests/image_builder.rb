require "uri"
require "socket"

module AYTests
  class ImageBuilder
    # Build a libvirt-kvm or a VirtualBox image using Veewee
    # https://github.com/jedi4ever/veewee

    include AYTests::Helpers

    attr_reader :sources_dir, :obs_iso_dir, :autoinst_path, :definition_path,
      :veewee_autoyast_dir, :libvirt_definition_path, :provider, :headless, :work_dir,
      :files_dir

    IMAGE_NAME = "autoyast"
    ISO_FILE_NAME = "testing.iso"
    IMAGE_BOX_NAME = "autoyast_vagrant_box_image_0.img"
    SLEEP_TIME_AFTER_UPGRADE = 150
    SLEEP_TIME_AFTER_SHUTDOWN = 15
    SSH_USER = "vagrant"
    SSH_PASSWORD = "nots3cr3t"
    SSH_ADDRESS = "127.0.0.1"
    SSH_PORT = "22"

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
    def initialize(sources_dir: nil, work_dir: nil, files_dir: nil, provider: :libvirt, headless: false)
      @sources_dir = sources_dir
      @work_dir = work_dir
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
      build
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
      change_boot_order
      backup_image
      build
      # During upgrade, Veewee will fail because SSH is disabled by PAM during
      # booting. So Veewee will get a "Authentication Failure" and it will give
      # up. At this time, we'll wait some time so installation process can finish
      # properly. We should find a cleaner solution.
      log.info "Waiting #{SLEEP_TIME_AFTER_UPGRADE} seconds for upgrade process to finish"
      sleep SLEEP_TIME_AFTER_UPGRADE
      run_postinstall
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
      Net::SSH::Simple.sync do
        log.info "Running post-install script"
        data = vm_ip(IMAGE_NAME)
        ssh data[:address], "sudo env postinstall.sh",
          { port: data[:port], user: SSH_USER, password: SSH_PASSWORD }
      end
    end

    private

    # Build a Vagrant image using Veewee
    #
    # @return [Boolean] true if the system was successfully built; return false
    #   otherwise.
    def build
      Dir.chdir(work_dir) do
        log.info "Creating #{veewee_provider} image"
        cmd = "veewee #{veewee_provider} build #{IMAGE_NAME} --force --auto"
        cmd << " --nogui" if headless
        system({ "AYTESTS_FILES_DIR" => files_dir.to_s }, cmd)
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
      raise "ERROR: #{autoinst} not found" unless autoinst.file?
      FileUtils.cp(autoinst, autoinst_path)
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
    # backup it and restore in Veewee's +after_create+ hook.
    def backup_image
      case provider
      when :libvirt
        system "sudo virt-clone -o #{IMAGE_NAME} -n #{IMAGE_NAME}_sav --file /var/lib/libvirt/images/#{IMAGE_NAME}_sav.qcow2"
      when :virtualbox
        # Shutdown the system
        system "VBoxManage controlvm #{IMAGE_NAME} acpipowerbutton"
        sleep SLEEP_TIME_AFTER_SHUTDOWN
        system "VBoxManage controlvm #{IMAGE_NAME} poweroff"

        # Copy the virtual machine (this is the only way of having an identical system)
        vm_config = `VBoxManage showvminfo #{IMAGE_NAME} | grep "Config file" | cut -f2 -d:`.strip
        vm_dir = File.dirname(vm_config)
        system "VBoxManage unregistervm #{IMAGE_NAME}"
        FileUtils.mv vm_dir, "#{vm_dir}.sav"
        system "sync"
      end
    end

    def vm_ip(name)
      case provider
      when :libvirt
        libvirt_vm_ip(name)
      when :virtualbox
        virtualbox_vm_ip(name)
      end
    end

    # Determine libvirt domain IP
    #
    # @param  [String] libvirt domain name
    # @return [Hash]   IP address and port
    def libvirt_vm_ip(name)
      mac = `sudo virsh domiflist #{name} | tail -n +3 | tr -s " " | cut -f 5 -d " "`.strip
      address = `arp | grep -i #{mac} | cut -f1 -d " "`.chomp
      { address: address, port: SSH_PORT }
    end

    # Determine VirtualBox VM IP
    #
    # @param  [String] VirtualBox machine name
    # @return [Hash]   IP address and port
    def virtualbox_vm_ip(name)
      mac_string = `VBoxManage showvminfo #{name} --machinereadable | grep Forwarding`
      data = mac_string.match(/.+="\w+,tcp,,(\d+),,22"/)
      port = data[1].to_i
      { address: SSH_ADDRESS, port: port }
    end

    # Prepare Veewee directory
    #
    # Create Veewee directory and copy post install script.
    def prepare
      FileUtils.mkdir_p(veewee_autoyast_dir) unless veewee_autoyast_dir.directory?
      FileUtils.cp(sources_dir.join("postinstall.sh"), veewee_autoyast_dir)
    end
  end
end
