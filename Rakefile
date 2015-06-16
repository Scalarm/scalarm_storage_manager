require 'yaml'
require 'json'
require 'mongo'
require 'sys/filesystem'

include Mongo

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)
require File.expand_path('../app/models/load_balancer_registration.rb', __FILE__)

ScalarmStorageManager::Application.load_tasks

namespace :log_bank do
  desc 'Start the service'
  task :start => :environment do
    %x[thin start -d -C config/thin.yml]
  end

  desc 'Stop the service'
  task :stop => :environment do
    %x[thin stop -C config/thin.yml]
  end
end

# configuration - path to a folder with database binaries
DB_BIN_PATH = File.join('.', 'mongodb', 'bin')
LOCAL_IP = UDPSocket.open {|s| begin s.connect("64.233.187.99", 1); s.addr.last rescue "127.0.0.1" end }

namespace :service do
  task :start => [:environment, 'db_instance:start', 'db_config_service:start', 'log_bank:start' ] do
    load_balancer_registration
  end

  task :stop => [:environment, 'log_bank:stop', 'db_config_service:stop', 'db_instance:stop' ] do
    load_balancer_deregistration
  end

  task :start_single => [:environment, 'db_instance:start_single', 'log_bank:start' ] do
    load_balancer_registration
  end

  task :stop_single => [:environment, 'log_bank:stop', 'db_instance:stop_single' ] do
    load_balancer_deregistration
  end
end

namespace :db_instance do
  desc 'Start DB instance'
  task :start => :environment do
    config = YAML.load_file("#{Rails.root}/config/scalarm.yml")

    unless File.exist?(File.join(DB_BIN_PATH, config['db_instance_dbpath']))
      %x[mkdir -p #{File.join(DB_BIN_PATH, config['db_instance_dbpath'])}]
    end

    #clear_instance(config)

    Rails.logger.debug(start_instance_cmd(config))
    Rails.logger.debug(%x[#{start_instance_cmd(config)}])

    information_service = InformationService.instance
    err, msg = information_service.register_service('db_instances', config['host'] || LOCAL_IP, config['db_instance_port'])

    if err
      puts "Fatal error while registering db instance '#{err}': #{msg}"
      return
    end

    # adding shard
    config_services = information_service.get_list_of('db_config_services')

    if config_services.empty?
      puts 'There is no DB Config Services registered'
    else
      puts "Adding the started db instance as a new shard --- #{config_services}"
      command = BSON::OrderedHash.new
      command['addShard'] = "#{config['host'] || LOCAL_IP}:#{config['db_instance_port']}"

      # this command can take some time - hence it should be called multiple times if necessary
      request_counter, response = 0, {}
      until request_counter >= 20 or response.has_key?('shardAdded')
        request_counter += 1

        begin
          response = run_command_on_local_router(command, information_service, config)
        rescue Exception => e
          puts "Error occured #{e}"
        end
        puts "Command #{request_counter} - #{response.inspect}"
        sleep 5
      end
    end
  end

  desc 'Stop DB instance'
  task :stop => :environment do
    config = YAML.load_file("#{Rails.root}/config/scalarm.yml")
    information_service = InformationService.instance

    # removing this shard from MongoDB cluster
    config_services = information_service.get_list_of('db_config_services')

    if config_services.blank?
      puts 'There is no DB config services'

    else
      puts 'Removing this instance shard from db cluster'
      command = BSON::OrderedHash.new
      command['listShards'] = 1

      list_shards_results = run_command_on_local_router(command, information_service, config)

      if list_shards_results['ok'] == 1
        shard = list_shards_results['shards'].find { |x| x['host'] == "#{config['host']}:#{config['db_instance_port']}" }

        if shard.nil?
          puts "Couldn't find shard with host set to #{config['host'] || LOCAL_IP}:#{config['db_instance_port']} - #{list_shards_results['shards'].inspect}"
        else
          command = BSON::OrderedHash.new
          command['removeshard'] = shard['_id']

          request_counter, response = 0, {}
          until request_counter >= 20 or response['state'] == 'completed'
            request_counter += 1

            begin
              response = run_command_on_local_router(command, information_service, config)
            rescue Exception => e
              puts "Error occured #{e}"
            end

            puts "Command #{request_counter} - #{response.inspect}"
            sleep 5
          end
        end

      else
        puts "List shards command failed - #{list_shards_results.inspect}"
      end
    end

    puts 'Killing the service process'
    kill_processes_from_list(proc_list('instance', config))
    puts 'Deregistering the service from Information Service'
    err, msg = information_service.deregister_service('db_instances', config['host'] || LOCAL_IP, config['db_instance_port'])

    if err
      puts "Fatal error while deregistering db instance '#{err}': #{msg}"
    end
  end

  desc 'Start a single DB instance in a non-sharded mode'
  task :start_single => :environment do
    # 1. read the config
    config = YAML.load_file("#{Rails.root}/config/scalarm.yml")

    # 2. create a db data folder if it doesn't exist
    unless File.exist?(File.join(DB_BIN_PATH, config['db_instance_dbpath']))
      %x[mkdir -p #{File.join(DB_BIN_PATH, config['db_instance_dbpath'])}]
    end

    # 3. start and a single instance without sharding on a db_router port
    log_append = File.exist?(config['db_instance_logpath']) ? '--logappend' : ''

    stat = Sys::Filesystem.stat('/')
    mb_available = stat.block_size * stat.blocks_available / 1024 / 1024

    start_instance_cmd = ["cd #{DB_BIN_PATH}",
      "./mongod --bind_ip #{config['host'] || LOCAL_IP} --port #{config['db_router_port']} " +
        "--dbpath #{config['db_instance_dbpath']} --logpath #{config['db_instance_logpath']} " +
        "--cpu --quiet --rest --fork #{log_append} #{mb_available < 5120 ? '--smallfiles' : ''}"
    ].join(';')

    Rails.logger.debug(start_instance_cmd)
    Rails.logger.debug(%x[#{start_instance_cmd}])

    # 4. register the instance as a db_router - then Experiment managers should connect to it
    information_service = InformationService.instance
    err, msg = information_service.register_service('db_routers', config['host'] || LOCAL_IP, config['db_router_port'])

    if err
      puts "Fatal error while registering a db instance in a single mode '#{err}': #{msg}"
    end
    # TODO we should probably to something here
  end

  desc 'Stop a DB instance started in a non-sharded mode'
  task :stop_single => :environment do
    # 1. reading the config
    config = YAML.load_file("#{Rails.root}/config/scalarm.yml")

    # 2. unregistering the instance from the routers' table
    information_service = InformationService.instance
    err, msg = information_service.deregister_service('db_routers', config['host'] || LOCAL_IP, config['db_router_port'])
    if err
      puts "Fatal error while deregistering db instance '#{err}': #{msg}"
      # TODO we should probably to something here
    end

    # 3. stopping the mongod process
    puts 'Killing the service process'
    proc_name = "./mongod .* --port #{config['db_router_port']}"
    out = %x[ps aux | grep "#{proc_name}"]
    instance_proc_list = out.split("\n").delete_if { |line| line.include? 'grep' }

    kill_processes_from_list(instance_proc_list)
  end

end

namespace :db_config_service do
  desc 'Start DB Config Service'
  task :start => :environment do
    config = YAML.load_file("#{Rails.root}/config/scalarm.yml")
    information_service = InformationService.instance

    unless File.exist?(File.join(DB_BIN_PATH, config['db_config_dbpath']))
      %x[mkdir -p #{File.join(DB_BIN_PATH, config['db_config_dbpath'])}]
    end
    #clear_config(config)

    puts start_config_cmd(config)
    puts %x[#{start_config_cmd(config)}]

    err, msg = information_service.register_service('db_config_services', config['host'] || LOCAL_IP, config['db_config_port'])

    if err
      puts "Fatal error while registering MongoDB config service '#{err}': #{msg}"
      return
    end

    puts "Starting router at: #{config['host'] || LOCAL_IP}:#{config['db_config_port']}"

    start_router("#{config['host'] || LOCAL_IP}:#{config['db_config_port']}", information_service, config)

    begin
      db = Mongo::Connection.new(config['host'] || LOCAL_IP).db('admin')
      # retrieve already registered shards and add them to this service
      information_service.get_list_of('db_instances').each do |db_instance_url|
        puts "DB instance URL: #{db_instance_url}"

        command = BSON::OrderedHash.new
        command['addShard'] = db_instance_url

        puts db.command(command).inspect
      end
    rescue Exception => e
      puts "An exception occurred during execution of the 'addShard' command: #{e}"
    end

    err, msg = information_service.register_service('db_routers', config['host'] || LOCAL_IP, config['db_router_port'])

    if err
      puts "Fatal error while registering MongoDB router '#{err}': #{msg}"
      return
    end
    #stop_router(config) if not is_router_run
  end

  desc 'Stop DB instance'
  task :stop => :environment do
    config = YAML.load_file("#{Rails.root}/config/scalarm.yml")
    information_service = InformationService.instance

    kill_processes_from_list(proc_list('router', config))
    kill_processes_from_list(proc_list('config', config))

    err, msg = information_service.deregister_service('db_config_services', config['host'] || LOCAL_IP, config['db_config_port'])

    if err
      puts "Fatal error while deregistering MongoDB config service '#{err}': #{msg}"
    end

    err, msg = information_service.deregister_service('db_routers', config['host'] || LOCAL_IP, config['db_router_port'])

    if err
      puts "Fatal error while deregistering MongoDB router '#{err}': #{msg}"
    end
  end
end

namespace :db_router do
  desc 'Start DB router'
  task :start => :environment do
    config = YAML.load_file("#{Rails.root}/config/scalarm.yml")
    information_service = InformationService.instance

    if service_status('router', config)
      stop_router(config)
    end

    config_services = information_service.get_list_of('db_config_services')
    config_service_url = config_services.sample

    return if config_service_url.nil?

    puts start_router_cmd(config_service_url, config)
    puts %x[#{start_router_cmd(config_service_url, config)}]

    err, msg = information_service.register_service('db_routers', config['host'] || LOCAL_IP, config['db_router_port'])

    if err
      puts "Fatal error while registering MongoDB router '#{err}': #{msg}"
      return
    end
  end

  desc 'Stop DB router'
  task :stop => :environment do
    config = YAML.load_file("#{Rails.root}/config/scalarm.yml")

    kill_processes_from_list(proc_list('router', config))
    information_service = InformationService.instance

    err, msg = information_service.deregister_service('db_routers', config['host'] || LOCAL_IP, config['db_router_port'])

    if err
      puts "Fatal error while deregistering MongoDB router '#{err}': #{msg}"
      return
    end
  end
end

namespace :load_balancer do
  desc 'Registration to load balancer'
  task :register do
    load_balancer_registration
  end

  desc 'Deregistration from load balancer'
  task :deregister do
    load_balancer_deregistration
  end
end

def clear_instance(config)
  puts "rm -rf #{DB_BIN_PATH}/#{config['db_instance_dbpath']}/*"
  puts %x[rm -rf #{DB_BIN_PATH}/#{config['db_instance_dbpath']}/*]
end

def start_instance_cmd(config)
  log_append = File.exist?(config['db_instance_logpath']) ? '--logappend' : ''

  stat = Sys::Filesystem.stat('/')
  mb_available = stat.block_size * stat.blocks_available / 1024 / 1024

  ["cd #{DB_BIN_PATH}",
    "./mongod --shardsvr --bind_ip #{config['host'] || LOCAL_IP} --port #{config['db_instance_port']} " +
      "--dbpath #{config['db_instance_dbpath']} --logpath #{config['db_instance_logpath']} " +
      "--cpu --quiet --rest --fork #{log_append} #{mb_available < 5120 ? '--smallfiles' : ''}"
  ].join(';')
end

def kill_processes_from_list(processes_list)
  processes_list.each do |process_line|
    pid = process_line.split(' ')[1]
    puts "kill -15 #{pid}"
    system("kill -15 #{pid}")
  end
end

def proc_list(service, config)
  proc_name = if service == 'router'
                "./mongos .* --port #{config['db_router_port']}"
              elsif service == 'config'
                "./mongod --configsvr .* --port #{config['db_config_port']}"
              elsif service == 'instance'
                "./mongod .* --port #{config['db_instance_port']}"
              end

  out = %x[ps aux | grep "#{proc_name}"]
  #puts out
  out.split("\n").delete_if { |line| line.include? 'grep' }
end

def run_command_on_local_router(command, information_service, config)
  result = {}
  config_services = information_service.get_list_of('db_config_services')

  unless config_services.blank?
    # url to any config service
    config_service_url = config_services.sample

    router_run = service_status('router', config)
    start_router(config_service_url, information_service, config)

    begin
      db = Mongo::Connection.new(config['host'] || LOCAL_IP).db('admin')
      result = db.command(command)
      puts result.inspect
      stop_router(config) if not router_run
    rescue Exception => e
      puts "An error occurred during command execution on MongoDB: #{e.inspect}"
      result['ok'] = 0
    end
  end

  result
end

def service_status(db_module, config)
  if proc_list(db_module, config).empty?
    puts "Scalarm DB #{db_module} is not running"
    false
  else
    puts "Scalarm DB #{db_module} is running"
    true
  end
end

def start_router(config_service_url, information_service, config)
  return if service_status('router', config)

  if config_service_url.nil?
    config_services = information_service.get_list_of('db_config_services')
    config_service_url = config_services.sample unless config_services.blank?
  end

  return if config_service_url.nil?

  puts start_router_cmd(config_service_url, config)
  puts %x[#{start_router_cmd(config_service_url, config)}]
end

def stop_router(config)
  kill_processes_from_list(proc_list('router', config))
end

# ./mongos --configdb eusas17.local:28000 --logpath /opt/scalarm_storage_manager/log/scalarm.log --fork
def start_router_cmd(config_db_url, config)
  log_append = File.exist?(config['db_router_logpath']) ? '--logappend' : ''

  ["cd #{DB_BIN_PATH}",
   "./mongos --bind_ip #{config['host'] || LOCAL_IP} --port #{config['db_router_port']} --configdb #{config_db_url} --logpath #{config['db_router_logpath']} --fork #{log_append}"
  ].join(';')
end

def clear_config(config)
  puts "rm -rf #{DB_BIN_PATH}/#{config['db_config_dbpath']}/*"
  puts %x[rm -rf #{DB_BIN_PATH}/#{config['db_config_dbpath']}/*]
end

# ./mongod --configsvr --dbpath /opt/scalarm_storage_manager/scalarm_db_data --port 28000 --logpath /opt/scalarm_storage_manager/log/scalarm_db.log --fork
def start_config_cmd(config)
  log_append = File.exist?(config['db_config_logpath']) ? '--logappend' : ''

  stat = Sys::Filesystem.stat('/')
  mb_available = stat.block_size * stat.blocks_available / 1024 / 1024

  ["cd #{DB_BIN_PATH}",
   "./mongod --configsvr --bind_ip #{config['host'] || LOCAL_IP} --port #{config['db_config_port']} " +
       "--dbpath #{config['db_config_dbpath']} --logpath #{config['db_config_logpath']} " +
       "--fork #{log_append} #{mb_available < 5120 ? '--smallfiles' : ''}"
  ].join(';')
end

def load_balancer_registration
  unless Rails.application.secrets.include? :load_balancer
    puts 'There is no configuration for load balancer in secrets.yml - LB registration will be disabled'
    return
  end
  unless Rails.env.test? or Rails.application.secrets.load_balancer["disable_registration"]
    LoadBalancerRegistration.register
  else
    puts 'load_balancer.disable_registration option is active'
  end
end

def load_balancer_deregistration
  unless Rails.application.secrets.include? :load_balancer
    puts 'There is no configuration for load balancer in secrets.yml - LB deregistration will be disabled'
    return
  end
  unless Rails.env.test? or Rails.application.secrets.load_balancer["disable_registration"]
    LoadBalancerRegistration.deregister
  else
    puts 'load_balancer.disable_registration option is active'
  end
end
