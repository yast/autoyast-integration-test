require "webrick"
require "webrick/https"
require "json"
require "uri"
require "aytests/certs_factory"
require "aytests/servlets/list_updates"

module AYTests
  # Implements a fake registration server
  #
  # The server will HTTPS and a new certificate will be created for each
  # instance using the given CA. WEBrick has its own way of creating certificates
  # automatically, but they're self-signed (so they won't work with YaST).
  #
  # Currently the server only implements the /connect/repositories/installer endpoint.
  class RegistrationServer
    # @return [Pathname] Path to CA certificate
    attr_reader :ca_crt_path
    # @return [Pathname] Path to CA key
    attr_reader :ca_key_path
    # @return [String]   IP address in which the server should address
    attr_reader :address
    # @return [Integer]  Port in which the server should address
    attr_reader :port
    # @return [URI]      Installer updates URL
    attr_reader :updates_url

    # Constructor
    #
    # @param ca_cert_ path [Pathname] Path to CA certificate
    # @param ca_key_path   [Pathname] Path to CA key
    # @param updates_url   [URI]      Installer updates URL
    # @param address       [String]   IP address in which the server should listen.
    #                                 Used as name certificate's CN.
    # @param port          [Integer]  Port in which the server should listen
    def initialize(ca_crt_path:, ca_key_path:, updates_url:, address: "127.0.0.1", port: 8889)
      @ca_crt_path = ca_crt_path
      @ca_key_path = ca_key_path
      @address     = address
      @port        = port
      @updates_url = updates_url
    end

    # Start the WEBrick server
    #
    # The server is launched in a separate thread.
    def start
      server.start
    end

    # Stop the WEBrick server
    def stop
      server.stop
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
    #
    # @see Servlets::ListUpdates
    def mount_endpoints
      server.mount("/connect/repositories/installer", Servlets::ListUpdates, URI(updates_url))
    end
  end
end
