require "webrick"
require "webrick/https"
require "json"
require "aytests/certs_factory"

module AYTests
  # Implements a fake registration server
  #
  # Currently it only implements the /connect/repositories/installer endpoint.
  class RegistrationServer
    # @return [Pathname] Path to CA certificate
    attr_reader :ca_crt_path
    # @return [Pathname] Path to CA certificate
    attr_reader :ca_key_path
    # @return [String]   IP address in which the server should address
    attr_reader :address
    # @return [Integer]  Port in which the server should address
    attr_reader :port

    # Constructor
    #
    # @param ca_cert_ path [Pathname] Path to CA certificate
    # @param ca_key_path   [Pathname] Path to CA key
    # @param address       [String]   IP address in which the server should listen
    # @param port          [Integer]  Port in which the server should listen
    def initialize(ca_crt_path:, ca_key_path:, address: "127.0.0.1", port: 8889)
      @ca_crt_path = ca_crt_path
      @ca_key_path = ca_key_path
      @address     = address
      @port        = port
    end

    # Start the WEBrick server
    def start
      server.start
    end

  private

    # Initializes the HTTPServer
    #
    # @return [WEBrick::HTTPServer]
    def server
      return @server if @server

      cert, key, ca = certs_factory.generate(address)
      @server = WEBrick::HTTPServer.new(:BindAddress => address, :Port => port,
        :SSLEnable => true, :SSLCertificate => cert, :SSLPrivateKey => key,
        :SSLClientCA => [ca], :SSLCACertificateFile => ca_crt_path.to_s)
      mount_endpoints
      @server
    end

    # Instantiates a certificates factory
    #
    # @return [AYTests::CertsFactory] Certificates factory
    def certs_factory
      @certs_factory ||= AYTests::CertsFactory.new(
        ca_crt_path: ca_crt_path, ca_key_path: ca_key_path
      )
    end

    # Mount endpoints on server
    #
    # When more endpoints are added, this code should be move to its own
    # servlet.
    def mount_endpoints
      server.mount_proc "/connect/repositories/installer" do |req, res|
        res["Content-Type"] = "application/json"
        res.body = JSON.generate([{
          'id' => 2101,
          'name' => 'SLES12-SP2-Installer-Updates',
          'distro_target' => 'sle-12-x86_64',
          'description' => 'SLES12-SP2-Installer-Updates for sle-12-x86_64',
          'url' => "https://#{address}/static/repos/sles12",
          'enabled' => false,
          'autorefresh' => true,
          'installer_updates' => true
        }])
      end
    end
  end
end
