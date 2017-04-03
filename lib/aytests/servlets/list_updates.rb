require "webrick/httpservlet"
require "json"

module AYTests
  module Servlets
    class ListUpdates < WEBrick::HTTPServlet::AbstractServlet
      PRODUCT = {
        "id"                => 2101,
        "name"              => "SLES12-SP2-Installer-Updates",
        "distro_target"     => "sle-12-x86_64",
        "description"       => "SLES12-SP2-Installer-Updates for sle-12-x86_64",
        "enabled"           => false,
        "autorefresh"       => true,
        "installer_updates" => true
      }.freeze

      # @return [URI] Updates URL
      attr_reader :updates_url

      # Constructor
      #
      # @param server     [WEBrick::HTTPServer] Server to attach the servlet
      # @param updates_url [URI] Updates URL
      def initialize(server, updates_url)
        super(server)
        @updates_url = updates_url
      end

      # Handle get requests
      #
      # @see WEBrick::HTTPServlet::AbstractServlet#do_GET
      def do_GET(_request, response)
        response.status = 200
        response["Content-Type"] = "application/json"
        response.body = JSON.generate(updates)
      end

      # Returns an array of updates repositories
      #
      # @return [Array] Array of update repositories
      def updates
        [PRODUCT.merge("url" => updates_url.to_s)]
      end
    end
  end
end
