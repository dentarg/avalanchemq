require "../controller"
require "./connections"
require "../../client/channel/consumer"

module AvalancheMQ
  class ConsumersController < Controller
    include ConnectionsHelper

    private def register_routes
      get "/api/consumers" do |context, _params|
        all_consumers(user(context)).to_json(context.response)
        context
      end

      get "/api/consumers/:vhost" do |context, params|
        with_vhost(context, params) do |vhost|
          user = user(context)
          refuse_unless_management(context, user, vhost)
          conns = connections(user).select { |conn| conn.vhost.name == vhost }
          consumers = Array(Client::Channel::Consumer).new
          conns.each do |conn|
            conn.channels.values.flat_map(&.consumers).each { |c| consumers << c }
          end
          consumers.to_json(context.response)
        end
      end
    end

    private def all_consumers(user)
      connections(user).flat_map { |c| c.channels.values.flat_map &.consumers }
    end
  end
end
