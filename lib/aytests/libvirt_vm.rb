require "rexml/document"
require "rexml/xpath"
require "cheetah"

module AYTests
  # Implements communication with Libvirt virtual machines.
  #
  # @see AYTests::VM
  class LibvirtVM
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
      @boot_order || REXML::XPath.match(@definition, "//os/boot").map { |d| d.attributes["dev"].to_sym }
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

    private

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
