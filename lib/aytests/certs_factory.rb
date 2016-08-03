module AYTests
  # Certificates factory
  #
  # Generates a certificate (with its corresponding key).
  class CertsFactory
    # @return [OpenSSL::X509::Certificate] CA certificate
    attr_reader :ca_crt
    # @return [OpenSSL::PKey::RSA] CA key
    attr_reader :ca_key

    # Highest serial number
    SERIAL_LIMIT = 9999
    # Certificates expiration time (in seconds)
    EXPIRATION   = 3600

    # Constructor
    #
    # @param ca_cert_ path [Pathname] Path to CA certificate
    # @param ca_key_path   [Pathname] Path to CA certificate
    def initialize(ca_crt_path:, ca_key_path:)
      @ca_crt = OpenSSL::X509::Certificate.new(ca_crt_path.read)
      @ca_key = OpenSSL::PKey::RSA.new(ca_key_path.read)
    end

    # Generates a new certificate/key
    #
    # @param name [String] Certificate's common name (CN)
    # @return [Array<OpenSSL::X509::Certificate OpenSSL::PKey::RSA, OpenSSL::X509::Certificate>]
    #         A triplet formed by: certificate, key and CA's certificate.
    def generate(name)
      keypair = OpenSSL::PKey::RSA.new(2048)

      req = generate_request(keypair, name)
      cert = generate_cert(req)

      [cert, keypair, ca_crt]
    end

    # Generates a certificate based on a request
    #
    # The certificate is signed with the CA's certificate/key
    #
    # @param req [OpenSSL::X509::Request] Certificate request
    # @return [OpenSSL::X509::Certificate] Generated certificate
    def generate_cert(req)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = rand(SERIAL_LIMIT)
      cert.not_before = Time.now
      cert.not_after = cert.not_before + 3600
      cert.public_key = req.public_key
      cert.subject = req.subject
      cert.issuer = ca_crt.subject

      cert.sign(ca_key, OpenSSL::Digest::SHA1.new)
    end

    # Generates a new signed request with a given name
    #
    # @param name [OpenSSL::PKey::RSA] Key pair to sign the certificate
    # @param name [String] Certificate's common name (CN)
    # @return [OpenSSL::X509::Request] Certificate request
    def generate_request(keypair, name)
      req = OpenSSL::X509::Request.new
      req.version = 0
      req.subject = OpenSSL::X509::Name.parse("CN=#{name}")
      req.public_key = keypair.public_key
      req.sign(keypair, OpenSSL::Digest::SHA1.new)
    end
  end
end
