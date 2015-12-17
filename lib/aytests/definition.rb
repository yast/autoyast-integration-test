require "cheetah"
require "rexml/document"
require "rexml/xpath"

module AYTests
  # Represents the definition of a virtual machine
  #
  # At this time, it only contains basic data: name, provider and MAC address.
  class Definition
    attr_accessor :name, :provider
    attr_reader :mac

    # Import the definition of a given machine
    #
    # @param [String]        name     Virtual machines' name
    # @param [String,Symbol] provider Provider (:libvirt or :virtualbox)
    # @return [AYTests::Definition] VM definition
    def self.import(name, provider)
      send("import_from_#{provider}", name)
    end

    # Import the definition of a given VirtualBox machine
    #
    # @param [String] name Virtual machines' name
    # @return [AYTests::Definition] VM definition
    def self.import_from_virtualbox(name)
      content = Cheetah.run(["VBoxManage", "showvminfo", "--machinereadable", name], stdout: :capture)
      match = /macaddress1="(\w+)"/.match(content)
      Definition.new(name: name, provider: :virtualbox, mac: match[1])
    end

    # Import the definition of a given Libvirt machine
    #
    # @param [String] name Virtual machines' name
    # @return [AYTests::Definition] VM definition
    def self.import_from_libvirt(name)
      xml = Cheetah.run(["sudo", "virsh", "dumpxml", name], stdout: :capture)
      doc = REXML::Document.new(xml)
      mac = REXML::XPath.first(doc, "//domain/devices/interface/mac/@address").value
      Definition.new(name: name, provider: :libvirt, mac: mac)
    end

    # Constructor
    #
    # @param [String]        name     Name
    # @param [String]        mac      MAC address
    # @param [String,Symbol] provider Provider (:libvirt or :virtualbox)
    def initialize(name: nil, mac: nil, provider: :libvirt)
      @name = name
      @provider = provider.to_sym
      self.mac = mac
    end

    # Set the MAC address
    #
    # It stores the value in XX:XX:XX:XX:XX:XX form.
    #
    # @param [String] value MAC address
    # @return [String,nil] Formatted MAC address or nil
    def mac=(value)
      @mac =
        if value.nil?
          nil
        elsif value =~ /\w{2}:\w{2}:\w{2}:\w{2}:\w{2}:\w{2}/
          value.downcase
        else
          value.downcase.unpack("a2"*6).join(":")
        end
    end
  end
end
