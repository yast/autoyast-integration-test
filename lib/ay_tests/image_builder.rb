require "uri"

module AYTests
  class ImageBuilder
    # * Builds a KVM image using veewee
    #   - It implies copying the ISO and the profile
    #   - If upgrade_, it will run the upgrade
    # * Export KVM image using veewee

    attr_reader :base_dir, :obs_iso_dir, :testing_iso_path, :log,
      :autoinst_path, :definition_path

    def initialize(base_dir: nil, log: nil)
      @base_dir = base_dir || AYTests.base_dir
      @obs_iso_dir = @base_dir.join("kiwi", "iso")
      @autoinst_path = @base_dir.join("kiwi", "definitions", "autoyast", "autoinst.xml")
      @definition_path = @base_dir.join("kiwi", "definitions", "autoyast", "definition.rb")
      @testing_iso_path = @base_dir.join("kiwi", "iso", "testing.iso")
      @log     = log || Logger.new(STDOUT)
    end

    def upgrade(autoinst, iso_url)
      # backup
      setup_iso(iso_url)
      setup_autoinst(autoinst)
      setup_definition(:upgrade)
      change_boot_order
      backup_image
      build
    end

    def install(autoinst, iso_url)
      setup_iso(iso_url)
      setup_autoinst(autoinst)
      setup_definition(:install)
      build
    end

    def export
      Dir.chdir(base_dir.join("kiwi")) do
        log.info "Exporting KVM image into box file"
        system "veewee kvm export autoyast --force"
      end
    end

    def cleanup
      FileUtils.rm(autoinst)
      log.error "Implement clean up"
    end

    def build
      log.info "Creating KVM image"
      Dir.chdir(File.join(base_dir, "kiwi")) do
        log.info "Building KVM image"
        system "veewee kvm build autoyast --force --auto"
      end
    end

    # nil: by default
    # url: IsoRepo
    # path: full file path
    def setup_iso(iso_url)
      iso_path = URI(iso_url.to_s).host ? IsoRepo.get(iso_url) : iso_url
      FileUtils.rm(obs_iso_dir.join("testing.iso"), force: true)
      FileUtils.ln_s(iso_path, obs_iso_dir.join("testing.iso"))
    end

    def setup_definition(mode)
      FileUtils.cp(base_dir.join("kiwi", "definitions", "autoyast", "#{mode}_definition.rb"),
                   definition_path)
    end

    def setup_autoinst(autoinst)
      raise "ERROR: #{autoinst} not found" unless autoinst.file?
      FileUtils.cp(autoinst, autoinst_path)
    end

    def change_boot_order
      autoyast_description = base_dir.join("kiwi", "autoyast_description.xml")
      system "sudo virsh destroy autoyast" #shutdown
      system "sudo virsh dumpxml autoyast >#{autoyast_description}"
      system "sed -i.bak s/dev=\\'cdrom\\'/dev=\\'cdrom_save\\'/g #{autoyast_description}"
      system "sed -i.bak s/dev=\\'hd\\'/dev=\\'cdrom\\'/g #{autoyast_description}"
      system "sed -i.bak s/dev=\\'cdrom_save\\'/dev=\\'hd\\'/g #{autoyast_description}"
      system "sudo virsh define #{autoyast_description}"
    end

    def backup_image
      system "sudo virt-clone -o autoyast -n autoyast_sav --file /var/lib/libvirt/images/autoyast_sav.qcow2"
    end

    def cleanup
      FileUtils.rm(autoinst_path, force: true)
      FileUtils.rm(definition_path, force: true)
    end
  end
end
