require "cheetah"

module AYTests
  # Implements communication with VirtualBox virtual machines.
  #
  # @see AYTests::VM
  class VirtualboxVM
    # By default, Libvirt devices names are used, so this driver needs to map
    # them to VirtualBox terminology.
    DEVICES_MAP = {
      disk: :hd,
      dvd:  :cdrom,
      net:  :network,
      fd:   :floppy,
      none: nil
    }.freeze
    RUNNING_STATE = "running".freeze
    SLEEP_TIME_AFTER_SHUTDOWN = 15

    attr_reader :name
    attr_writer :boot_order, :mac

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
      return @boot_order if @boot_order
      devices = (1..4).map do |i|
        DEVICES_MAP[@definition["boot#{i}"].to_sym]
      end
      @boot_order = devices.compact
    end

    # Return the MAC address
    #
    # Only 1 network adapter is considered
    #
    # @return [String] MAC address in MAC-48 form (00:00:00:00:00:00)
    def mac
      @mac || @definition["macaddress1"].unpack("a2" * 6).join(":")
    end

    # Save changes to the virtual machine
    #
    # It relies on `VBoxManage` to update the definition.
    def save
      # VBoxManage requires MAC addresses without ":". It reports invalid MAC otherwise
      Cheetah.run(["VBoxManage", "modifyvm", name, "--macaddress1", mac.delete(":")] +
        boot_order_to_options)
      read_definition
    end

    # Adding/Updating devices of the virtual machine
    #
    # @param [String] kind of the device e.g. "network" (just for information)
    # @param [String] params of the given divice
    def add_device(kind, params)
      Cheetah.run(["VBoxManage", "modifyvm", name] + params.split)
    end

    # Backup the virtual machine
    #
    # If the machine is running, it will be switched off before creating the
    # backup. Copying the files is the only way of having an identical system
    # in VirtualBox.
    #
    # @param [String] backup_name Backup name.
    #
    # @see restore
    def backup(backup_name)
      shutdown if running?
      Cheetah.run(["VBoxManage", "unregistervm", name])
      FileUtils.mv(vm_directory, vm_directory.join("..", backup_name))
      system "sync"
    end

    # Restore a backup into the current machine
    #
    # @param [String] backup_name Name of the backup to be restored.
    #
    # @see backup
    def restore!(backup_name)
      Cheetah.run(["VBoxManage", "unregistervm", name, "--delete"])
      FileUtils.mv(vm_directory.join("..", backup_name), vm_directory)
      Cheetah.run(["VBoxManage", "registervm", config_file.to_s])
      system "sync"
      read_definition
    end

    # Destroy the virtual machine
    def destroy!
      system "VBoxManage unregistervm #{name} --delete"
    end

    # Shutdown the machine
    #
    # It simulates pushing the ACPI power button and, after
    # SLEEP_TIME_AFTER_SHUTDOWN seconds, try to power it off
    # if it still running.
    def shutdown
      Cheetah.run(["VBoxManage", "controlvm", name, "acpipowerbutton"])
      sleep SLEEP_TIME_AFTER_SHUTDOWN
      Cheetah.run(["VBoxManage", "controlvm", name, "poweroff"]) if running?
    end

    # Determine whether the machine is running or not
    #
    # @return [Boolean] true if it's running; otherwise, it returns false.
    def running?
      vmstate = Cheetah.run(["VBoxManage", "showvminfo", "--machinereadable", name],
        ["grep", "VMState"], stdout: :capture)
      match = /VMState="(\w+)"/.match(vmstate)
      match[1] == RUNNING_STATE
    end

    # Take a screenshot of the virtual machine
    #
    # @param [String,Pathname] File path to save the screenshot
    def screenshot(path)
      Cheetah.run(["VBoxManage", "controlvm", name, "screenshotpng", path])
      true
    rescue Cheetah::ExecutionFailed
      false
    end

  private

    # Determine the virtual machine's configuration file
    #
    # This path is stored as CfgFile in the virtual machine's definition.
    #
    # @return [Pathname] Configuration file's path
    def config_file
      Pathname.new(@definition["CfgFile"])
    end

    # Determine the virtual machine's directory
    #
    # @return [Pathname] Virtual machine's directory
    #
    # @see config_file
    def vm_directory
      config_file ? config_file.dirname : nil
    end

    # Convert boot_order to command line options for VBoxManage
    #
    # @example
    #   vm.boot_order            #=> [:hd, :network]
    #   vm.boot_order_to_options #=> ["--boot1", "disk", "--boot2", "net",
    #                                 "--boot3", "none", "--boot4", "none"]
    #
    # @return [Array<String>] Options for VBoxManage to set up boot order
    #
    # @see #virtualbox_boot_order
    def boot_order_to_options
      order = virtualbox_boot_order
      (1..4).reduce([]) do |options, idx|
        options + ["--boot#{idx}", order[idx - 1].to_s]
      end
    end

    # Convert boot_order devices to VirtualBox terminology
    #
    # @example
    #   vm.boot_order            #=> [:hd, :network]
    #   vm.virtualbox_boot_order #=> [:disk, :net]
    #
    # @return [Array<String>] Boot order represented as VirtualBox devices
    def virtualbox_boot_order
      devices = Array.new(4, "none")
      boot_order.each_with_index do |device, idx|
        devices[idx] = DEVICES_MAP.key(device)
      end
      devices
    end

    # Read the virtual machine's definition
    #
    # The definition is stored in the instance variable @definition.
    #
    # @return [Hash] Virtual machine's definition
    def read_definition
      content = Cheetah.run(["VBoxManage", "showvminfo",
                             "--machinereadable", name], stdout: :capture)
      @definition = content.split("\n").each_with_object({}) do |line, definition|
        key, value = line.split("=")
        definition[unquote(key)] = unquote(value)
      end
    end

    # Remove double-quotes from the beginning and the end of a string
    #
    # @example Remove double-quotes
    #   unquote('"some quote"') #=> "some quote"
    #
    # @param [String] string String to be unquoted
    # @return [String] String without double-quotes at beginning or end.
    def unquote(string)
      string.sub(/\A"/, "").sub(/"\Z/, "")
    end
  end
end
