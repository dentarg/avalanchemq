require "router"
require "logger"

module AvalancheMQ
  abstract class Controller
    include Router

    @log : Logger
    def initialize(@amqp_server : AvalancheMQ::Server)
      @log = @amqp_server.log.dup
      @log.progname += " " + self.class.name.split("::").last
      register_routes
    end

    private abstract def register_routes

    private def redirect_back(context)
      context.response.headers["Location"] = context.request.headers["Referer"]
      halt(context, 302)
    end

    private def parse_body(context)
      raise HTTPServer::ExpectedBodyError.new if context.request.body.nil?
      ct = context.request.headers["Content-Type"]? || nil
      if ct.nil? || ct.empty? || ct == "application/json"
        JSON.parse(context.request.body.not_nil!)
      else
        raise HTTPServer::UnknownContentType.new("Unknown Content-Type: #{ct}")
      end
    end

    private def not_found(context, message = "Not found")
      halt(context, 404, { error: "not_found", reason: message })
    end

    private def bad_request(context, message = "Bad request")
      halt(context, 400, { error: "bad_request", reason: message })
    end

    private def access_refused(context, message = "Access refused")
      halt(context, 401, { error: "access_refused", reason: message })
    end

    private def halt(context, status_code, body = nil)
      context.response.status_code = status_code
      body.try &.to_json(context.response)
      raise HaltRequest.new(body.try { |b| b[:reason] })
    end

    private def with_vhost(context, params, key = "vhost")
      vhost = URI.unescape(params[key])
      if @amqp_server.vhosts[vhost]?
        yield vhost
      else
        not_found(context, "VHost #{vhost} does not exist")
      end
      context
    end

    private def user(context) : User
      user = nil
      if username = context.authenticated_username?
        user = @amqp_server.users[username]?
      end
      unless user
        @log.warn "Authorized user not in user store"
        access_refused(context)
      end
      user
    end

    def vhosts(user : User, require_amqp_access = true)
      @amqp_server.vhosts.select do |v|
        full_view_vhosts_access = user.tags.any? { |t| t.administrator? || t.monitoring? }
        amqp_access = user.permissions.has_key?(v.name)
        mgmt = user.tags.any? { |t| t.management? || t.policy_maker? }
        if require_amqp_access
          next amqp_access && (full_view_vhosts_access || mgmt)
        else
          next full_view_vhosts_access || (mgmt && amqp_access)
        end
      end
    end

    private def refuse_unless_management(context, user, vhost = nil)
      vhost_access = vhost.nil? || user.permissions.has_key?(vhost)
      unless vhost_access
        @log.debug { "user=#{user.name} does not have management access on vhost=#{vhost}" }
        access_refused(context)
      end
    end

    private def refuse_unless_policymaker(context, user, vhost = nil)
      refuse_unless_management(context, user, vhost)
      unless user.tags.any? { |t| t.policy_maker? || t.administrator? }
        @log.debug { "user=#{user.name} does not have policymaker access on vhost=#{vhost}" }
        access_refused(context)
      end
    end

    private def refuse_unless_monitoring(context, user)
      refuse_unless_management(context, user)
      unless user.tags.any? { |t| t.administrator? || t.monitoring? }
        @log.debug { "user=#{user.name} does not have monitoring access" }
        access_refused(context)
      end
    end

    private def refuse_unless_administrator(context, user : User)
      refuse_unless_policymaker(context, user)
      refuse_unless_monitoring(context, user)
      unless user.tags.any? &.administrator?
        @log.debug { "user=#{user.name} does not have administrator access" }
        access_refused(context)
      end
    end
    class HaltRequest < Exception; end
  end
end
