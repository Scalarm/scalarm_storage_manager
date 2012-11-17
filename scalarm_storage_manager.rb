require "yaml"
require "socket"
require_relative "model/scalarm_db"
require_relative "model/scalarm_log_bank"

# utilities functions
class ScalarmStorageManager

  def self.create_service(service_name, service_param)
    config_file_path = File.join("etc", "config.yaml")
    if not File.exist?(config_file_path)
      raise "Could not read configuration file."
    end

    config = YAML::load_file config_file_path

    if service_name == "db"
      ScalarmDb.new(config, service_param)
    elsif service_name == "log_bank"
      ScalarmLogBank.new(config)
    else
      nil
    end

  end

  def initialize
    config_file_path = File.join("etc", "config.yaml")
    if not File.exist?(config_file_path)
      raise "Could not read configuration file."
    end

    @config = YAML::load_file config_file_path

    @host = ""
    UDPSocket.open { |s| s.connect('64.233.187.99', 1); @host = s.addr.last }
  end

end

# ======================= MAIN =======================
if ARGV.size < 2 or not ["db", "log_bank"].include?(ARGV[1])
  puts "[usage] ruby scalarm_storage_manager.rb (start | stop | status | clear) db (router | config | instance)"
  puts "or      ruby scalarm_storage_manager.rb (start | stop | status | clear) log_bank"
  exit 1
end

command, service_name, service_param = ARGV

begin
  service = ScalarmStorageManager.create_service(service_name, service_param)
  service.execute(command)
rescue Exception => e
  puts "Error: #{e}"
end
