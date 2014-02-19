require 'yaml'
require 'json'
require 'mongo'
require 'sys/filesystem'

include Mongo

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

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

  desc 'Removing unnecessary digests on production'
  task non_digested: :environment do
    Rake::Task['assets:precompile'].execute
    assets = Dir.glob(File.join(Rails.root, 'public/assets/**/*'))
    regex = /(-{1}[a-z0-9]{32}*\.{1}){1}/
    assets.each do |file|
      next if File.directory?(file) || file !~ regex

      source = file.split('/')
      source.push(source.pop.gsub(regex, '.'))

      non_digested = File.join(source)
      FileUtils.cp(file, non_digested)
    end
  end
end

# configuration - path to a folder with database binaries
DB_BIN_PATH = File.join('.', 'mongodb', 'bin')
LOCAL_IP = UDPSocket.open {|s| s.connect('64.233.187.99', 1); s.addr.last}
CONFIG = YAML.load_file("#{Rails.root}/config/scalarm.yml")

namespace :db_instance do
  desc 'Start DB instance'
  task :start => :environment do
    unless File.exist?(File.join(DB_BIN_PATH, CONFIG['db_instance_dbpath']))
      %x[mkdir -p #{File.join(DB_BIN_PATH, CONFIG['db_instance_dbpath'])}]
    end

    slog('db_instance', start_instance_cmd(CONFIG))
    slog('db_instance', %x[#{start_instance_cmd(CONFIG)}])

    information_service = InformationService.new(CONFIG['information_service_url'],
                                                 CONFIG['information_service_user'], CONFIG['information_service_pass'])
    db_instance_host = CONFIG['host'] || LOCAL_IP

    # adding shard
    config_services = JSON.parse(information_service.get_list_of('db_config_services'))

    if config_services.blank?
      slog('db_instance', 'There is no DB Config Services registered')
    else
      slog('db_instance', "Adding the started db instance as a new shard --- #{config_services}")
      command = BSON::OrderedHash.new
      command['addShard'] = "#{db_instance_host}:#{CONFIG['db_instance_port']}"

      # this command can take some time - hence it should be called multiple times if necessary
      run_command_on_local_router(command, information_service){|response| response.has_key?('shardAdded')}
    end

    information_service.register_service('db_instances', db_instance_host, CONFIG['db_instance_port'])
  end

  desc 'Stop DB instance'
  task :stop => :environment do
    information_service = InformationService.new(CONFIG['information_service_url'],
                                                 CONFIG['information_service_user'], CONFIG['information_service_pass'])
    db_instance_host = CONFIG['host'] || LOCAL_IP

    config_services = JSON.parse(information_service.get_list_of('db_config_services'))

    if config_services.blank?
      slog('init', 'There is no DB config services')
    else
      slog('init', 'Removing this instance shard from db cluster')
      command = BSON::OrderedHash.new
      command['listShards'] = 1

      list_shards_results = run_command_on_local_router(command, information_service){|response| response['ok'] == 1 }

      if list_shards_results['ok'] == 1
        shard = list_shards_results['shards'].find { |x| x['host'] == "#{db_instance_host}:#{CONFIG['db_instance_port']}" }

        if shard.nil?
          slog('db_instance', "There is no shard at '#{db_instance_host}:#{CONFIG['db_instance_port']}' configured")
        else
          command = BSON::OrderedHash.new
          command['removeshard'] = shard['_id']

          run_command_on_local_router(command, information_service){|response| response['state'] == 'completed'}
        end

      else
        slog('db_instance', "List shards command failed - #{list_shards_results.inspect}")
      end
    end

    kill_processes_from_list(proc_list('instance', CONFIG))
    information_service.deregister_service('db_instances', db_instance_host, CONFIG['db_instance_port'])
  end

  desc 'Remove DB instance data folder'
  task :clean => :environment do
    slog('db_instance', "rm -rf #{DB_BIN_PATH}/#{CONFIG['db_instance_dbpath']}/*")
    slog('db_instance', %x[rm -rf #{DB_BIN_PATH}/#{CONFIG['db_instance_dbpath']}/*])
  end
end

namespace :db_config_service do
  desc 'Start DB Config Service'
  task :start => :environment do
    unless File.exist?(File.join(DB_BIN_PATH, CONFIG['db_config_dbpath']))
      %x[mkdir -p #{File.join(DB_BIN_PATH, CONFIG['db_config_dbpath'])}]
    end

    information_service = InformationService.new(CONFIG['information_service_url'],
                                                 CONFIG['information_service_user'], CONFIG['information_service_pass'])
    db_config_service_host = CONFIG['host'] || LOCAL_IP

    #clear_config(config)
    slog('db_config_service', start_config_cmd(CONFIG))
    slog('db_config_service', %x[#{start_config_cmd(CONFIG)}])

    information_service.register_service('db_config_services', db_config_service_host, CONFIG['db_config_port'])

    # retrieve already registered shards and add them to this service
    JSON.parse(information_service.get_list_of('db_instances')).each do |db_instance_url|
      slog('db_config_service', "Registering shard from #{db_instance_url}")

      command = BSON::OrderedHash.new
      command['addShard'] = db_instance_url

      run_command_on_local_router(command, information_service){|response| response.has_key?('shardAdded')}
    end

  end

  desc 'Stop DB instance'
  task :stop => :environment do
    information_service = InformationService.new(CONFIG['information_service_url'],
                                                 CONFIG['information_service_user'], CONFIG['information_service_pass'])
    db_config_service_host = CONFIG['host'] || LOCAL_IP

    kill_processes_from_list(proc_list('config', CONFIG))

    information_service.deregister_service('db_config_services', db_config_service_host, CONFIG['db_config_port'])
  end

  desc 'Remove DB Config Service data folder'
  task :clean => :environment do
    slog('db_config_service', "rm -rf #{DB_BIN_PATH}/#{CONFIG['db_config_dbpath']}/*")
    slog('db_config_service', %x[rm -rf #{DB_BIN_PATH}/#{CONFIG['db_config_dbpath']}/*])
  end
end

namespace :db_router do
  desc 'Start DB router'
  task :start => :environment do
    information_service = InformationService.new(CONFIG['information_service_url'],
                                                 CONFIG['information_service_user'], CONFIG['information_service_pass'])

    if service_status('router', CONFIG)
      stop_router(CONFIG)
    end
    # look up for a random registered config service
    config_services = JSON.parse(information_service.get_list_of('db_config_services'))
    config_service_url = config_services.sample

    return if config_service_url.nil?

    slog('db_router', start_router_cmd(config_service_url, CONFIG))
    slog('db_router', %x[#{start_router_cmd(config_service_url, CONFIG)}])

    db_router_host = CONFIG['db_router_host'] || CONFIG['host'] || LOCAL_IP

    if db_router_host != 'localhost'
      information_service.register_service('db_routers', db_router_host, CONFIG['db_router_port'])
    end
  end

  desc 'Stop DB router'
  task :stop => :environment do
    kill_processes_from_list(proc_list('router', CONFIG))
    information_service = InformationService.new(CONFIG['information_service_url'],
                                                 CONFIG['information_service_user'], CONFIG['information_service_pass'])

    db_router_host = CONFIG['db_router_host'] || CONFIG['host'] || LOCAL_IP
    if db_router_host != 'localhost'
      information_service.deregister_service('db_routers', db_router_host, CONFIG['db_router_port'])
    end
  end
end

#============================ UTIL FUNCTIONS ============================
def start_instance_cmd(config)
  log_append = File.exist?(config['db_instance_logpath']) ? '--logappend' : '--logappend'

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

def run_command_on_local_router(command, information_service, &block)
  result = {}
  config_services = JSON.parse(information_service.get_list_of('db_config_services'))

  unless config_services.blank?
    # url to any config service
    config_service_url = config_services.sample

    router_run = service_status('router', CONFIG)
    start_router(config_service_url, information_service, CONFIG)

    db = Mongo::Connection.new('localhost').db('admin')

    1.upto(10) do
      result = db.command(command)
      slog('init', "DB command response: #{result.inspect}")

      if yield(result)
        break
      else
        sleep 3
      end
    end

    stop_router(CONFIG) if not router_run
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
    config_services = JSON.parse(information_service.get_list_of('db_config_services'))
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
  log_append = File.exist?(config['db_router_logpath']) ? '--logappend' : '--logappend'
  host = config['db_router_host'] || config['host'] || LOCAL_IP

  ["cd #{DB_BIN_PATH}",
   "./mongos --bind_ip #{host} --port #{config['db_router_port']} --configdb #{config_db_url} --logpath #{config['db_router_logpath']} --fork #{log_append}"
  ].join(';')
end

# ./mongod --configsvr --dbpath /opt/scalarm_storage_manager/scalarm_db_data --port 28000 --logpath /opt/scalarm_storage_manager/log/scalarm_db.log --fork
def start_config_cmd(config)
  log_append = File.exist?(config['db_config_logpath']) ? '--logappend' : '--logappend'

  stat = Sys::Filesystem.stat('/')
  mb_available = stat.block_size * stat.blocks_available / 1024 / 1024

  ["cd #{DB_BIN_PATH}",
   "./mongod --configsvr --bind_ip #{config['host'] || LOCAL_IP} --port #{config['db_config_port']} " +
       "--dbpath #{config['db_config_dbpath']} --logpath #{config['db_config_logpath']} " +
       "--fork #{log_append} #{mb_available < 5120 ? '--smallfiles' : ''}"
  ].join(';')
end
