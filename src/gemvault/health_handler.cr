require "http/server"
require "json"

module Gemvault
  # Health checks currently describe only this skeleton process.
  # Storage and registry readiness checks are implemented with their services.
  class HealthHandler
    include HTTP::Handler

    def call(context : HTTP::Server::Context) : Nil
      request = context.request

      unless request.method.in?("GET", "HEAD")
        return call_next(context)
      end

      case request.path
      when "/health/live"
        respond(context, {"status" => "ok", "check" => "process"})
      when "/health/ready"
        respond(context, {"status" => "ok", "checks" => {"configuration" => "ok"}})
      else
        call_next(context)
      end
    end

    private def respond(context : HTTP::Server::Context, body) : Nil
      json = body.to_json
      response = context.response
      response.status = HTTP::Status::OK
      response.content_type = "application/json"
      response.content_length = json.bytesize
      response.print(json) unless context.request.method == "HEAD"
    end
  end
end
