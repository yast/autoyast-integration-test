require "forwardable"
require "net/ssh/simple"

module AYTests
  # This class allows to query and modify virtual machines attributes.
  # The communication with the virtual machines is implemented in
  # separated classes (LibvirtVM and VirtualboxVM).
  class VM
    extend Forwardable

    # Default user to use when connecting through SSH
    DEFAULT_SSH_USER = "vagrant".freeze
    # Default SSH port
    DEFAULT_SSH_PORT = 22

    def_delegators :@driver, :mac, :mac=, :boot_order, :boot_order=, :stop,
      :backup, :restore!, :running?, :screenshot

    attr_reader :driver, :name

    # Constructor
    #
    # @param [String]        name     Virtual machine name
    # @param [String,Symbol] provider Virtual machine provider
    def initialize(name, provider)
      driver_class = "#{provider.capitalize}VM"
      @name = name
      require "aytests/#{provider}_vm"
      @driver = AYTests.const_get(driver_class).new(name)
    end

    # Update virtual machine attributes and saves the new definition
    #
    # This is just a convenience method to save some keystrokes.
    #
    # @param [Hash] attrs Attributes and values to save
    # @see #save
    def update(attrs)
      attrs.each do |meth, value|
        send("#{meth}=", value)
      end
      @driver.save
    end

    # Run a command in the virtual machine using SSH
    #
    # @param cmd [String] Command
    # @param user     [String]          SSH username
    # @param password [String]          SSH user password
    # @param port     [Integer]         SSH port
    # @return [Boolean] true if the operation was successful; false otherwise
    def run(cmd, port:, user:, password:)
      result = Net::SSH::Simple.ssh(ip, cmd,
        user: user, port: port, password: password, paranoid: false)
      result[:exit_code].zero?
    end

    # Download a file from the virtual machine using SCP
    #
    # @param remote   [Pathname,String] Remote file name
    # @param remote   [Pathname,String] Local file name (where to put the file)
    # @param user     [String]          SSH username
    # @param password [String]          SSH user password
    # @param port     [Integer]         SSH port
    # @return [Boolean] true if the operation was successful; false otherwise
    def download(remote, local, port:, user:, password:)
      Net::SSH::Simple.scp_get(ip, remote.to_s, local.to_s,
        user: user, port: port, password: password, paranoid: false)
      true
    rescue Net::SSH::Simple::Error
      false
    end

    # Determine virtual machine IP
    #
    # @return [String] IP address
    def ip
      arp = Cheetah.run(["arp", "-n"], stdout: :capture)
      entry = arp.lines.find { |a| a.include?(mac) }
      return nil if entry.nil?
      entry.split(" ")[0]
    end
  end
end
