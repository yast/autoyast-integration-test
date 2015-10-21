require "uri"

module AYTests
  class ImageBuilder
    # Build a libvirt-kvm image using Veewee
    # https://github.com/jedi4ever/veewee

    include AYTests::Helpers

    attr_reader :base_dir, :obs_iso_dir, :autoinst_path, :definition_path,
      :kiwi_autoyast_dir, :libvirt_definition_path

    IMAGE_NAME = "autoyast"

    # Constructor
    #
    # @param [Pathname] base_dir Set the base directory. By default it uses
    #   AYTests.base_dir.
    def initialize(base_dir = nil)
      @base_dir = base_dir || AYTests.base_dir
      @obs_iso_dir = @base_dir.join("kiwi", "iso")
      @kiwi_autoyast_dir = @base_dir.join("kiwi", "definitions", "autoyast")
      @autoinst_path = kiwi_autoyast_dir.join("autoinst.xml")
      @definition_path = kiwi_autoyast_dir.join("definition.rb")
      # This file will be used by Veewee during upgrade.
      @libvirt_definition_path = @base_dir.join("kiwi", "autoyast_description.xml")
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
    def upgrade(autoinst, iso_url)
      setup_iso(iso_url)
      setup_autoinst(autoinst)
      setup_definition(:upgrade)
      change_boot_order
      backup_image
      build
    end

    # Export the created machine
    #
    # @return [Boolean] true if the system was successfully exported; false
    #   otherwise.
    def export
      Dir.chdir(base_dir.join("kiwi")) do
        log.info "Exporting KVM image into box file"
        system "veewee kvm export #{IMAGE_NAME} --force"
      end
    end

    # Clean up used files
    #
    # Removes AutoYaST profile, Veewee definition and link to installation ISO
    def cleanup
      FileUtils.rm(autoinst_path, force: true)
      FileUtils.rm(definition_path, force: true)
      FileUtils.rm(obs_iso_dir.join("testing.iso"), force: true)
      FileUtils.rm(libvirt_definition_path, force: true)
    end

    private

    # Build a KVM image using Veewee
    #
    # @return [Boolean] true if the system was successfully built; return false
    #   otherwise.
    def build
      log.info "Creating KVM image"
      Dir.chdir(base_dir.join("kiwi")) do
        log.info "Building KVM image"
        system "veewee kvm build #{IMAGE_NAME} --force --auto"
      end
    end

    # Set up the ISO image
    #
    # It will link the ISO image through a link called +testing.iso+.
    # The directory where this link will live is determined through
    # the #obs_iso_dir method.
    #
    # It rely on AYTests::IsoRepo class so local and remote locations
    # are supported.
    #
    # @see obs_iso_dir
    def setup_iso(iso_url)
      iso_path = URI(iso_url.to_s).host ? IsoRepo.get(iso_url) : iso_url
      FileUtils.rm(obs_iso_dir.join("testing.iso"), force: true)
      FileUtils.ln_s(iso_path, obs_iso_dir.join("testing.iso"))
    end

    # Set up the definition
    #
    # It copies the Veewee definition depending on the mode. Definitions
    # will live in kiwi/definitions/autoyast under base directory.
    #
    # @param [String|Symbol] mode :install for installation or :upgrade for upgrade.
    def setup_definition(mode)
      FileUtils.cp(kiwi_autoyast_dir.join("#{mode}_definition.rb"), definition_path)
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
      system "sudo virsh destroy #{IMAGE_NAME}" # shutdown
      system "sudo virsh dumpxml #{IMAGE_NAME} >#{libvirt_definition_path}"
      system "sed -i.bak s/dev=\\'cdrom\\'/dev=\\'cdrom_save\\'/g #{libvirt_definition_path}"
      system "sed -i.bak s/dev=\\'hd\\'/dev=\\'cdrom\\'/g #{libvirt_definition_path}"
      system "sed -i.bak s/dev=\\'cdrom_save\\'/dev=\\'hd\\'/g #{libvirt_definition_path}"
      system "sudo virsh define #{libvirt_definition_path}"
      FileUtils.rm(definition, force: true)
    end

    # Backup image
    #
    # The image will be destroyed be Veewee when starting the upgrade. So we need to
    # backup it and restore in Veewee's +after_create+ hook.
    def backup_image
      system "sudo virt-clone -o #{IMAGE_NAME} -n #{IMAGE_NAME}_sav --file /var/lib/libvirt/images/#{IMAGE_NAME}_sav.qcow2"
    end
  end
end
