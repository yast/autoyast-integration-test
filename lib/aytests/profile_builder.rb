require "aytests/definition"

module AYTests
  # Responsible for tweaking the AutoYaST profile before using it.
  #
  # @see #build
  class ProfileBuilder
    attr_reader :name, :autoinst_path, :provider, :definition

    # Constructor
    #
    # @param [String] name     Virtual machine's name
    # @param [String,Pathname] AutoYaST profile path
    # @param [String,Symbol]   Provider (:libvirt or :virtualbox)
    def initialize(name, autoinst_path, provider)
      @definition = AYTests::Definition.import(name, provider)
      @autoinst_path = autoinst_path
      @provider = provider.to_sym
    end

    # Return the tweaked AutoYaST profile
    #
    # * %IP% is replaced with local IP (the host's IP, not the VM's one).
    # * %MAC% is replaced with the VM MAC address.
    # * /dev/vd* hard disk devices are replaced with /dev/sd* when using
    #   :virtualbox.
    #
    # @return [String] Tweaked AutoYaST profile
    def build
      content = File.read(autoinst_path)
      content.gsub!("/dev/vd", "/dev/sd") if provider == :virtualbox
      content.gsub!("%MAC%", definition.mac)
      content.gsub!("%IP%", local_ip)
      content
    end

    private

    # Determine the host IP
    #
    # @return [String] Host IP address.
    #
    # Taken from Veewee to make sure that the IP matches.
    def local_ip
      # turn off reverse DNS resolution temporarily
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true

      UDPSocket.open do |s|
        s.connect '64.233.187.99', 1 # google
        s.addr.last
      end
    ensure
      Socket.do_not_reverse_lookup = orig
    end
  end
end
