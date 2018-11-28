require "logger"

module AvalancheMQ
  class Config
    def initialize(
      @data_dir = "",
      @log_level : Logger::Severity = Logger::INFO,
      @bind = "::",
      @port = 5672,
      @tls_port = 5671,
      @cert_path = "",
      @key_path = "",
      @mgmt_bind = "::",
      @mgmt_port = 15672,
      @mgmt_tls_port = 15671,
      @mgmt_cert_path = "",
      @mgmt_key_path = "",
      @heartbeat = 60_u16,
      @stats_interval = 5000
    )
    end

    property data_dir, log_level, bind, port, tls_port, cert_path, key_path, mgmt_bind, mgmt_port,
      mgmt_tls_port, mgmt_cert_path, mgmt_key_path, heartbeat, stats_interval

    def parse(file)
      return if file.empty?
      abort "Config could not be found" unless File.file?(file)
      ini = INI.parse(File.read(file))
      ini.each do |section, settings|
        case section
        when "main"
          @data_dir = settings["data_dir"]? || @data_dir
          @log_level = Logger::Severity.parse?(settings["log_level"]?.to_s) || @log_level
          @stats_interval = settings["stats_interval"]?.try &.to_i32 || @stats_interval
        when "amqp"
          @bind = settings["bind"]? || @bind
          @port = settings["port"]?.try &.to_i32 || @port
          @tls_port = settings["tls_port"]?.try &.to_i32 || @tls_port
          @cert_path = settings["tls_cert"]? || @cert_path
          @key_path = settings["tls_key"]? || @key_path
          @heartbeat = settings["heartbeat"]?.try &.to_u16 || @heartbeat
        when "mgmt"
          @mgmt_bind = settings["bind"]? || @mgmt_bind
          @mgmt_port = settings["port"]?.try &.to_i32 || @mgmt_port
          @mgmt_tls_port = settings["tls_port"]?.try &.to_i32 || @mgmt_tls_port
          @mgmt_cert_path = settings["tls_cert"]? || @mgmt_cert_path
          @mgmt_key_path = settings["tls_key"]? || @mgmt_key_path
        end
      end
    end
  end
end