require_relative "../spec_helper"
require "aytests/servlets/list_updates"
require "uri"

RSpec.describe AYTests::Servlets::ListUpdates do
  subject(:servlet) { AYTests::Servlets::ListUpdates.new(server, URI(updates_url)) }

  let(:response) { double("response").as_null_object }
  let(:request) { double("request") }
  let(:server) { double("server").as_null_object }
  let(:updates_url) { "https://updates.suse.com/sles12" }

  describe "#do_GET" do
    it "sets response code to 200" do
      expect(response).to receive(:status=).with(200)
      servlet.do_GET(request, response)
    end

    it "sets the content-type to 'application/json'" do
      expect(response).to receive(:[]=).with("Content-Type", "application/json")
      servlet.do_GET(request, response)
    end

    it "sets the body with updates_url information" do
      expect(response).to receive(:body=).with(/#{updates_url}/)
      servlet.do_GET(request, response)
    end
  end
end
