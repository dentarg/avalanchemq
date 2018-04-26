require "http/server"
require "json"
require "logger"
require "router"
require "./handler/error_handler"
require "./handler/defaults_handler"
require "./controller"
require "./controller/definitions"
require "./controller/connections"
require "./controller/main"
require "./controller/static"

module AvalancheMQ
  class HTTPServer
    @log : Logger

    @running = false

    def initialize(@amqp_server : AvalancheMQ::Server, @port : Int32)
      @log = @amqp_server.log.dup
      @log.progname = "HTTP(#{port})"
    end

    def listen
      @running = true
      handlers = [
        ApiDefaultsHandler.new,
        ApiErrorHandler.new(@log),
        StaticController.new("./static").route_handler,
        MainController.new(@amqp_server).route_handler,
        DefinitionsController.new(@amqp_server).route_handler,
        ConnectionsController.new(@amqp_server).route_handler
      ] of HTTP::Handler
      handlers.unshift(HTTP::LogHandler.new) if @log.level == Logger::DEBUG
      @http = HTTP::Server.new(@port, handlers)
      server = @http.not_nil!.bind
      @log.info "Listening on #{server.local_address}"
      @http.not_nil!.listen
    end

    def close
      @http.try &.close
    end

    def closed?
      !@running
    end

    class NotFoundError < Exception; end
    class ExpectedBodyError < ArgumentError; end
    class UnknownContentType < Exception; end
  end
end