module AYTests
  # Implements communication with VirtualBox virtual machines.
  #
  # @see AYTests::VM
  class VirtualboxVM
    # By default, Libvirt devices names are used, so this driver needs to map
    # them to VirtualBox terminology.
    DEVICES_MAP = {
       disk: :hd,
       dvd: :cdrom,
       net: :network,
       fd: :floppy,
       none: nil
    }

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
      @mac || @definition["macaddress1"].unpack("a2"*6).join(":")
    end


    # Save changes to the virtual machine
    #
    # It relies on `VBoxManage` to update the definition.
    def save
      Cheetah.run(["VBoxManage", "modifyvm", name, "--macaddress1", @mac] + boot_order_to_options)
      read_definition
    end

    private

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
        options += ["--boot#{idx}", order[idx-1].to_s]
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
      @definition = content.split("\n").reduce({}) do |definition, line|
        key, value = line.split("=")
        definition[unquote(key)] = unquote(value)
        definition
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
