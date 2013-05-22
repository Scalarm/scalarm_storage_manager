require 'optparse'
require 'yaml'
require 'socket'

require_relative 'services/log_bank_service'
require_relative 'services/db_service'

options = {}

opt_parser = OptionParser.new do |opt|
  opt.banner = 'Usage: ruby scalarm_storage_manager.rb COMPONENT COMMAND [OPTIONS]'
  opt.separator  ''
  opt.separator  'Components'
  opt.separator  '    log_bank: a service for storing simulation outputs in a scalable way'
  opt.separator  '    db: a scalable database for experiments metadata'
  opt.separator  ''
  opt.separator  'Commands'
  opt.separator  '    start: start component'
  opt.separator  '    stop: stop component'
  opt.separator  ''
  opt.separator  'Modules'
  opt.separator  '    router: an access point to a database cluster'
  opt.separator  '    config: a configuration service for database'
  opt.separator  '    instance: an actual instance of a database'
  opt.separator  ''
  opt.separator  'Options'

  opt.on('-m', '--db_module MODULE', 'which module of the db you want to run') do |db_module|
    options[:db_module] = db_module
  end

  opt.on('-h', '--help', 'help') do
    puts opt_parser
  end
end

opt_parser.parse!

# creating information service proxy
require_relative 'model/information_service'

info_service_config = YAML.load_file("#{__dir__}/etc/config.yml")
information_service = Scalarm::InformationService.new(info_service_config['information_service_host'], info_service_config['information_service_port'],
                                                      info_service_config['information_service_login'], info_service_config['information_service_password'])

case ARGV[0]

  when 'log_bank'
    puts "Calling the '#{ARGV[1]}' command for log_bank with #{options.inspect}"
    # reading config from a file
    storage_manager_root = File.split(File.expand_path($0)).first
    config_file_path = File.join(storage_manager_root, 'etc', 'log_bank.yml')
    config = YAML.load_file(config_file_path)
    # reading global configs
    port = config['port'].to_i || 20000
    host = config['host']
    # pinging google to get ip of our host
    UDPSocket.open { |s| s.connect('64.233.187.99', 1); host = s.addr.last } if host.nil?

    pid_file = config['pid_file'] || File.join(storage_manager_root, 'tmp', "scalarm_log_bank_#{port}.pid")

    case ARGV[1]
      when 'start'
        Scalarm.start_log_bank(host, port, pid_file, information_service)
      when 'stop'
        Scalarm.stop_log_bank(host, port, pid_file, information_service)
      else
        puts "Command #{ARGV[1]} is not supported"
    end

  when 'db'
    puts "Calling the '#{ARGV[1]}' command for db with #{options.inspect}"
    db_module = options[:db_module]

    storage_manager_root = File.split(File.expand_path($0)).first
    config_file_path = File.join(storage_manager_root, 'etc', 'scalarm_db.yml')
    config = YAML.load_file(config_file_path)

    begin
      db_service = Scalarm::DbService.new(config, db_module, information_service)
      db_service.send(ARGV[1])
    rescue Exception => e
      puts "Error occurred while calling #{ARGV[1]} - #{e}"
    end

  else
    puts opt_parser

end
