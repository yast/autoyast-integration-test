require "webrick"

module AYTests
  # Implement a dummy web server used with Veewee
  class WebServer
    # @param veewee_dir [Pathname,String] Directory to serve under /
    # @param files_dir  [Pathname,String] Directory to serve under /static
    # @param port       [Integer]         Port to listen
    def initialize(veewee_dir:, files_dir:, port: 8888)
      @server = WEBrick::HTTPServer.new(Port: port)
      @server.mount "/", WEBrick::HTTPServlet::FileHandler, veewee_dir.to_s
      @server.mount "/static", WEBrick::HTTPServlet::FileHandler, files_dir.to_s
    end

    # Start the server
    def start
      @server.start
    end
  end
end
