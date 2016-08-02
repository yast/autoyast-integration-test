require "spec_helper"
require "aytests/registration_server"

RSpec.describe AYTests::RegistrationServer do
  SSL_DIR = TEST_DIR.join("..", "share", "veewee", "ssl")
  let(:ca_crt_path) { SSL_DIR.join("rootCA.pem") }
  let(:ca_key_path) { SSL_DIR.join("rootCA.key") }
  let(:address) { "localhost" }
  let(:port) { 9000 }
  let(:http_server) { double("http_server") }
  let(:certs_factory) { double("certs factory") }

  subject(:server) do
    AYTests::RegistrationServer.new(
      ca_crt_path: ca_crt_path,
      ca_key_path: ca_key_path,
      address:     address,
      port:        port
    )
  end

  describe "#start" do
    it "initializes a HTTPS server" do
      expect(WEBrick::HTTPServer).to receive(:new) do |args|
        expect(args[:Port]).to eq(port)
        expect(args[:SSLEnable]).to eq(true)
        expect(args[:SSLCertificate]).to be_a(OpenSSL::X509::Certificate)
        expect(args[:SSLPrivateKey]).to be_a(OpenSSL::PKey::RSA)
      end.and_call_original
      expect_any_instance_of(WEBrick::HTTPServer).to receive(:start)

      server.start
    end
  end
end
