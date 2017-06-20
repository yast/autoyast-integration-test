require "rexml/document"
require "rexml/xpath"
require "cheetah"
require "mini_magick"

module AYTests
  # Implements communication with Libvirt virtual machines.
  #
  # @see AYTests::VM
  class LibvirtVM
    attr_reader :name
    attr_writer :boot_order, :mac

    RUNNING_STATE = "running".freeze
    SLEEP_TIME_AFTER_SHUTDOWN = 15

    # Constructor
    #
    # @param [String] name Virtual machine name
    def initialize(name)
      @name = name
      read_definition
    end

    # Return the boot order
    #
    # @return [Array<Symbol>] Array of devices ordered by boot priority
    #
    # @example Boot from hard disk first
    #   vm.boot_order #=> [:hd, :cdrom]
    def boot_order
      @boot_order ||
        REXML::XPath.match(@definition, "//os/boot").map { |d| d.attributes["dev"].to_sym }
    end

    # Return the MAC address
    #
    # Only 1 network adapter is considered
    #
    # @return [String] MAC address in MAC-48 form (00:00:00:00:00:00)
    def mac
      @mac || REXML::XPath.first(@definition, "//domain/devices/interface/mac/@address").value
    end

    # Save changes to the virtual machine
    #
    # It relies on the tool `virt-xml` to update the definition.
    def save
      Cheetah.run(["sudo", "virt-xml", name, "--edit", "--network", "mac=#{@mac}"])
      Cheetah.run(["sudo", "virt-xml", name, "--edit", "--boot", @boot_order.join(",")])
      read_definition
    end

    # Adding one device to the virtual machine
    #
    # @param [String] kind of the device e.g. "network"
    # @param [String] params of the given divice
    def add_device(kind, params)
      Cheetah.run(["sudo", "virt-xml", name, "--add-device", "--#{kind}", params])
    end

    # Backup the virtual machine
    #
    # If the machine is running, it will be switched off before creating the
    # backup.
    #
    # @param [String] backup_name A name for the backup.
    #
    # @see restore!
    def backup(backup_name)
      shutdown if running?
      copy(name, backup_name)
    end

    # Restore a backup into the current machine
    #
    # @param [String] backup_name Name of the backup to be restored.
    def restore!(backup_name)
      copy(backup_name, name)
      self.class.new(backup_name).destroy!
      read_definition
    end

    # Destroy the virtual machine
    def destroy!
      Cheetah.run(["sudo", "virsh", "undefine", name, "--remove-all-storage"])
    end

    # Shutdown the virtual machine
    #
    # If after SLEEP_TIME_AFTER_SHUTDOWN seconds the machine isn't stopped,
    # then it will powered off.
    def shutdown
      Cheetah.run(["sudo", "virsh", "shutdown", name])
      sleep SLEEP_TIME_AFTER_SHUTDOWN
      Cheetah.run(["sudo", "virsh", "destroy", name]) if running?
    end

    # Determine whether the machine is running or not
    #
    # @return [Boolean] true if it's running; otherwise, it returns false.
    def running?
      state = Cheetah.run(["sudo", "virsh", "domstate", name], stdout: :capture).strip
      state == RUNNING_STATE
    end

    # Take a screenshot of the virtual machine
    #
    # @param [String,Pathname] File path to save the screenshot
    def screenshot(path)
      pnm_path = path.sub_ext(".pnm").to_s
      Cheetah.run(["sudo", "virsh", "screenshot", name, "--file", pnm_path])
      MiniMagick::Tool::Convert.new { |c| c << pnm_path << path.to_s }
      # Although the call has returned correclty there is still a snapshot
      # process running. Maybe there is a virsh problem here.
      # So trying to kill it explicit.
      Cheetah.run(["sudo", "pkill", "-f", "virsh screenshot"], allowed_exitstatus: 1)
      true
    rescue Cheetah::ExecutionFailed
      false
    end

  private

    # Copy a virtual machine into another one
    #
    # It relies in virt-clone to do the job. If the target machine exists, it
    # will be overwritten.
    #
    # @param [String] source Name of the original machine.
    # @param [String] target Name of the cloned machine.
    def copy(source, target)
      Cheetah.run(["sudo", "virt-clone", "-o", source, "-n", target, "--auto-clone", "--replace"])
    end

    # Read the virtual machine's definition
    #
    # The definition is stored in the instance variable @definition.
    #
    # @return [REXML::Document] Virtual machine's definition
    def read_definition
      xml = Cheetah.run(["sudo", "virsh", "dumpxml", name], stdout: :capture)
      @definition = REXML::Document.new(xml)
    end
  end
end
