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

# TODO: db_instance_dbpath should not be relative to DB_BIN_PATH
# because it makes difficult to use external mongo if available

# configuration - path to a folder with database binaries
DB_BIN_PATH = File.join('.', 'mongodb', 'bin')
LOCAL_IP = UDPSocket.open {|s| begin s.connect("64.233.187.99", 1); s.addr.last rescue "127.0.0.1" end }

# task :enable_mongo_active_record_init do
#   ENV['SKIP_MONGO_ACTIVE_RECORD_INIT'] = nil
# end
#
# task :disable_mongo_active_record_init do
#   ENV['SKIP_MONGO_ACTIVE_RECORD_INIT'] = '1'
# end

namespace :service do
  task :start => ['service:ensure_config',
                  'db_instance:start', 'db_config_service:start', 'log_bank:start' ] do
    load_balancer_registration
  end

  task :stop => ['log_bank:stop', 'db_config_service:stop', 'db_instance:stop' ] do
    load_balancer_deregistration
  end

  task :start_single => ['service:ensure_config', 'db_instance:start_single', 'log_bank:start' ] do
    load_balancer_registration
  end

  task :stop_single => ['log_bank:stop', 'db_instance:stop_single' ] do
    load_balancer_deregistration
  end

  desc 'Create default configuration files if these do not exist'
  task :ensure_config do
    copy_example_config_if_not_exists('config/secrets.yml')
    copy_example_config_if_not_exists('config/scalarm.yml')
    copy_example_config_if_not_exists('config/thin.yml')
  end
end

namespace :log_bank do
  desc 'Start the service'
  task :start => ['service:ensure_config', :environment] do
    if Rails.application.secrets.service_key.nil?
      command = "thin start -d -C config/thin.yml"
    else
      command = "thin start -d --ssl --ssl-key-file #{Rails.application.secrets.service_key} --ssl-cert-file #{Rails.application.secrets.service_crt} -C config/thin.yml"
    end

    puts command
    %x[#{command}]
  end

  desc 'Stop the service'
  task :stop => :environment do
    %x[thin stop -C config/thin.yml]
  end

  desc 'Restart the service'
  task :restart => [:stop, :start] do
    puts 'Restarting log_bank...'
  end
end

def create_mongo_relative_dir(dir_name)
  unless File.exist?(File.join(DB_BIN_PATH, dir_name))
    %x[mkdir -p #{File.join(DB_BIN_PATH, dir_name)}]
  end
end

namespace :db_instance do
  desc 'Start DB instance'
  task :start => ['service:ensure_config'] do
    config = load_database_config

    create_mongo_relative_dir(config['db_instance_dbpath'])

    #clear_instance(config)

    puts start_instance_cmd(config)
    puts %x[#{start_instance_cmd(config)}]

    information_service = information_service_instance(read_secrets)
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
          puts "Error occured on run command on local router: #{e}"
        end
        puts "Command #{request_counter} - #{response.inspect}"
        sleep 5
      end
    end
  end

  desc 'Stop DB instance'
  task :stop do
    config = load_database_config
    information_service = information_service_instance(read_secrets)

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

            puts "Command on run command on local router: #{request_counter} - #{response.inspect}"
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
  task :start_single => ['service:ensure_config'] do
    # 1. read the config
    config = load_database_config

    # 2. create a db data folder if it doesn't exist
    create_mongo_relative_dir(config['db_instance_dbpath'])

    # 3. start and a single instance without sharding on a db_router port
    log_append = File.exist?(config['db_instance_logpath']) ? '--logappend' : ''

    stat = Sys::Filesystem.stat('/')
    mb_available = stat.block_size * stat.blocks_available / 1024 / 1024

    enable_auth = config['auth_username'] || config['auth_password']

    cmd = start_single_instance_cmd(config, enable_auth)

    puts(cmd)
    puts(%x[#{cmd}])

    # 4. register the instance as a db_router - then Experiment managers should connect to it
    information_service = information_service_instance(read_secrets)
    err, msg = information_service.register_service('db_routers',
                                                    config['host'] || config['db_router_host'] || LOCAL_IP,
                                                    config['db_router_port'] || 27017)

    if err
      puts "Fatal error while registering a db instance in a single mode '#{err}': #{msg}"
    end
    # TODO we should probably to something here
  end

  desc 'Stop a DB instance started in a non-sharded mode'
  task :stop_single do
    # 1. reading the config
    config = load_database_config

    # 2. unregistering the instance from the routers' table
    information_service = information_service_instance(read_secrets)
    err, msg = information_service.deregister_service('db_routers',
                                                      config['host'] || config['db_router_host'] || LOCAL_IP,
                                                      config['db_router_port'] || 27017)
    if err
      puts "Fatal error while deregistering db instance '#{err}': #{msg}"
      # TODO we should probably to something here
    end

    # 3. stopping the mongod process
    puts 'Killing the service process'
    kill_mongod(config['db_router_port'])
  end

  desc 'Create database with authentication'
  task :create_auth do
    config = load_database_config

    unless config['auth_username'] and config['auth_password']
      raise 'Missing configuration: both auth_username and auth_password are required to create_auth'
    end

    username, password = config['auth_username'], config['auth_password']

    create_mongo_relative_dir(config['db_instance_dbpath'])

    ## start mongod without auth to enable user creation
    cmd = start_single_instance_cmd(config.merge('host' => 'localhost', 'db_router_host' => 'localhost'), false)
    puts(cmd)
    puts(%x[#{cmd}])

    unless $? == 0
      raise 'mongod process failed - please read logs for more details'
    end

    begin
      client = nil
      3.times do
        begin
          client = Mongo::Connection.new('localhost')
          break
        rescue Mongo::ConnectionFailure
          puts 'mongod not ready yet, will try in 2 seconds again...'
          sleep 2
        end
      end

      ## Databases specified in config file
      ## If you want to add more, you must do it manually
      db_names = [config['db_name'],
                  config['binaries_collection_name'],
                  (config['monitoring'] && config['monitoring']['db_name'])].reject {|name| name.nil?}

      ## Add user for each database
      db_names.each do |db_name|
        puts "Will add user #{config['auth_username']} to #{db_name} database..."
        db = client[db_name]
        db.add_user(username, password, nil, roles: ['readWrite'])
      end

      ## Add root user with the same credentials
      client['admin'].add_user(username, password, nil, roles: %w(readWriteAnyDatabase userAdmin dbAdmin))
    ensure
      kill_mongod(config['db_router_port'])
    end
  end

end

def kill_mongod(port)
  puts 'Terminating mongod processes'
  proc_name = "./mongod .* --port #{port}"
  out = %x[ps aux | grep "#{proc_name}"]
  instance_proc_list = out.split("\n").delete_if { |line| line.include? 'grep' }

  kill_processes_from_list(instance_proc_list)
end

namespace :db_config_service do
  desc 'Start DB Config Service'
  task :start do
    config = load_database_config
    information_service = information_service_instance(read_secrets)

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
  task :stop do
    config = load_database_config
    information_service = information_service_instance(read_secrets)

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
  task :start do
    config = load_database_config
    information_service = information_service_instance(read_secrets)

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
  task :stop do
    config = load_database_config

    kill_processes_from_list(proc_list('router', config))
    information_service = information_service_instance(read_secrets)

    err, msg = information_service.deregister_service('db_routers', config['host'] || LOCAL_IP, config['db_router_port'])

    if err
      puts "Fatal error while deregistering MongoDB router '#{err}': #{msg}"
      return
    end
  end
end

namespace :load_balancer do
  desc 'Registration to load balancer'
  task :register => :environment do
    load_balancer_registration
  end

  desc 'Deregistration from load balancer'
  task :deregister => :environment do
    load_balancer_deregistration
  end
end

def clear_instance(config)
  puts "rm -rf #{DB_BIN_PATH}/#{config['db_instance_dbpath']}/*"
  puts %x[rm -rf #{DB_BIN_PATH}/#{config['db_instance_dbpath']}/*]
end


def start_instance_cmd(config, auth=false)
  bind_ip = (config['host'] || LOCAL_IP)
  generic_start_instance_cmd(config, bind_ip, config['db_instance_port'], true, auth)
end

def start_single_instance_cmd(config, auth=false)
  bind_ip = (config['host'] || config['db_router_host'] || LOCAL_IP)
  bind_port = (config['db_router_port'] || 27017)
  generic_start_instance_cmd(config, bind_ip, bind_port, false, auth)
end

def generic_start_instance_cmd(config, bind_ip, port, shardsrv=true, auth=false)
  log_append = File.exist?(config['db_instance_logpath']) ? '--logappend' : ''

  fs_stat = Sys::Filesystem.stat('/')
  mb_available = fs_stat.block_size * fs_stat.blocks_available / 1024 / 1024
  smallfiles = config['force_smallfiles'] || (mb_available < 5120)

  ## notice: removed --quiet at 19-06-2015
  ["cd #{DB_BIN_PATH}",
    "./mongod #{shardsrv ? "--shardsvr" : ''} --bind_ip #{bind_ip} --port #{port} " +
      "--dbpath #{config['db_instance_dbpath']} --logpath #{config['db_instance_logpath']} " +
      "--cpu --rest --httpinterface --fork #{log_append} #{smallfiles ? '--smallfiles' : ''} " +
        " #{auth ? '--auth' : '--noauth'}"
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
   "./mongos --bind_ip #{config['db_router_host'] || config['host'] || LOCAL_IP} --port #{config['db_router_port']} --configdb #{config_db_url} --logpath #{config['db_router_logpath']} --fork #{log_append}"
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

def copy_example_config_if_not_exists(base_name, prefix='example')
  config = base_name
  example_config = "#{base_name}.example"

  unless File.exists?(config)
    puts "Copying #{example_config} to #{config}"
    FileUtils.cp(example_config, config)
  end
end

def load_database_config
  YAML.load_file("#{Rails.root}/config/scalarm.yml")
end

def read_secrets
  YAML.load(ERB.new(File.read("#{Rails.root}/config/secrets.yml")).result)[ENV['RAILS_ENV'] || 'development']
end

def information_service_instance(config)
  require 'scalarm/service_core/information_service'

  Scalarm::ServiceCore::InformationService.new(
      config['information_service_url'],
      config['information_service_user'],
      config['information_service_pass'],
      !!config['information_service_development']
  )
end
