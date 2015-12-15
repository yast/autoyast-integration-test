require "webrick"

module AYTests
  class WebServer
    def initialize(veewee_dir:, files_dir:, name: "autoyast", port: 8888)
      @server = WEBrick::HTTPServer.new(:Port => port)
      @server.mount "/", WEBrick::HTTPServlet::FileHandler, veewee_dir.to_s
      @server.mount "/static", WEBrick::HTTPServlet::FileHandler, files_dir.to_s
    end

    def start
      @server.start
    end
  end
end
