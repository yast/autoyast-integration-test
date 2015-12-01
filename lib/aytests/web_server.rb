require "webrick"
require "pathname"

module AYTests
  class WebServer
    def initialize(base_dir:, name: "autoyast", port: 8888)
      base_dir = Pathname.new(base_dir)
      root = base_dir.join("kiwi", "definitions", name)
      static = base_dir.join("files", "static")
      @server = WEBrick::HTTPServer.new(:Port => port)
      @server.mount "/", WEBrick::HTTPServlet::FileHandler, root.to_s
      @server.mount "/static", WEBrick::HTTPServlet::FileHandler, static.to_s
    end

    def start
      @server.start
    end
  end
end
