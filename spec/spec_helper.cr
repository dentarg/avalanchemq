require "spec"
require "file_utils"
require "amqp-client"
require "../src/avalanchemq/config"
require "../src/avalanchemq/server"
require "../src/avalanchemq/log_formatter"
require "../src/avalanchemq/http/http_server"
require "http/client"
require "uri"

FileUtils.rm_rf("/tmp/spec")

{% if flag?(:verbose) %}
  LOG_LEVEL = Logger::DEBUG
{% elsif flag?(:warn) %}
  LOG_LEVEL = Logger::WARN
{% else %}
  LOG_LEVEL = Logger::ERROR
{% end %}

AMQP_PORT      = ENV.fetch("AMQP_PORT", "5672").to_i
AMQPS_PORT     = ENV.fetch("AMQPS_PORT", "5671").to_i
AMQP_BASE_URL  = "amqp://localhost:#{AMQP_PORT}"
AMQPS_BASE_URL = "amqps://localhost:#{AMQPS_PORT}"
HTTP_PORT      = ENV.fetch("HTTP_PORT", "8080").to_i
BASE_URL       = "http://localhost:#{HTTP_PORT}"

unless ENV["CI"]?
  Spec.override_default_formatter(Spec::VerboseFormatter.new)
end

module TestHelpers
  class_property s, h

  def self.setup
    {% unless flag?(:skipServerSetup) %}
      create_servers
    {% end %}
  end

  def s
    TestHelpers.s.not_nil!
  end

  def h
    TestHelpers.h.not_nil!
  end

  def with_channel(**args)
    name = nil
    if formatter = Spec.formatters[0].as?(Spec::VerboseFormatter)
      name = formatter.@last_description
    end
    conn = AMQP::Client.new(**args.merge(port: AvalancheMQ::Config.instance.amqp_port, name: name)).connect
    ch = conn.channel
    yield ch
  ensure
    conn.try &.close(no_wait: false)
  end

  def with_ssl_channel(**args)
    with_channel(args) { |ch| yield ch }
  end

  def wait_for(timeout = 5.seconds)
    sec = Time.monotonic
    loop do
      Fiber.yield
      res = yield
      return res if res
      raise "Execuction expired" if Time.monotonic - sec > timeout
    end
  end

  def test_headers(headers = nil)
    req_hdrs = HTTP::Headers{"Content-Type"  => "application/json",
                             "Authorization" => "Basic Z3Vlc3Q6Z3Vlc3Q="} # guest:guest
    req_hdrs.merge!(headers) if headers
    req_hdrs
  end

  def close_servers
    s.close
    h.close
  end

  def self.create_servers(dir = "/tmp/spec", level = LOG_LEVEL)
    log = Logger.new(STDERR, level: level)
    AvalancheMQ::LogFormatter.use(log)
    cfg = AvalancheMQ::Config.instance
    cfg.gc_segments_interval = 1
    cfg.queue_max_acks = 10
    cfg.segment_size = 512 * 1024
    cfg.amqp_bind = "localhost"
    cfg.amqp_port = AMQP_PORT
    cfg.amqps_port = AMQPS_PORT
    cfg.http_bind = "localhost"
    cfg.http_port = HTTP_PORT
    @@s = AvalancheMQ::Server.new(dir, log.dup)
    @@h = AvalancheMQ::HTTP::Server.new(@@s.not_nil!, log.dup)
    @@h.not_nil!.bind_tcp(cfg.http_bind, cfg.http_port)
    spawn { @@s.try &.listen(cfg.amqp_bind, cfg.amqp_port) }
    cert = Dir.current + "/spec/resources/server_certificate.pem"
    key = Dir.current + "/spec/resources/server_key.pem"
    ctx = OpenSSL::SSL::Context::Server.new
    ctx.certificate_chain = cert
    ctx.private_key = key
    spawn { @@s.try &.listen_tls(cfg.amqp_bind, cfg.amqps_port, ctx) }
    spawn { @@h.try &.listen }
    Fiber.yield
  end

  def get(path, headers = nil)
    HTTP::Client.get("#{BASE_URL}#{path}", headers: test_headers(headers))
  end

  def post(path, headers = nil, body = nil)
    HTTP::Client.post("#{BASE_URL}#{path}", headers: test_headers(headers), body: body)
  end

  def put(path, headers = nil, body = nil)
    HTTP::Client.put("#{BASE_URL}#{path}", headers: test_headers(headers), body: body)
  end

  def delete(path, headers = nil, body = nil)
    HTTP::Client.delete("#{BASE_URL}#{path}", headers: test_headers(headers), body: body)
  end
end

extend TestHelpers
TestHelpers.setup
