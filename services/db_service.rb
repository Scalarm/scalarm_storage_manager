require_relative '../model/information_service'
require 'mongo'

module Scalarm

  class DbService
    # configuration - path to a folder with database binaries
    DB_BIN_PATH = File.join('.', 'mongodb-linux-x86_64-2.4.3', 'bin')

    def initialize(config, db_module, information_service)
      @config = config
      @db_module = db_module
      @information_service = information_service

      # getting ip of the current host
      @host = @config['host']
      # pinging google to get ip of our host
      UDPSocket.open { |s| s.connect('64.233.187.99', 1); @host = s.addr.last } if @host.nil?
    end

    def start
      self.send "start_#{@db_module}"
    end

    def stop
      self.send "stop_#{@db_module}"
    end

    def status
      service_status(@db_module)
    end

    def clear
      self.send "clear_#{@db_module}"
    end

    # all DB service related functions - START STOP STATUS CLEAR - for instance config and router
    private

    def start_instance
      unless File.exist?(File.join(DB_BIN_PATH, @config['db_instance_dbpath']))
        %x[mkdir -p #{File.join(DB_BIN_PATH, @config['db_instance_dbpath'])}]
      end
      clear_instance

      puts start_instance_cmd
      puts %x[#{start_instance_cmd}]

      # TODO we should check if there is an already registered config service

      # register in information service
      @information_service.send_request('register_db_instance', { server: @host, port: @config['db_instance_port'] })
      # adding shard
      puts 'Adding the started db instance as a new shard'
      command = BSON::OrderedHash.new
      command['addShard'] = "#{@host}:#{@config['db_instance_port']}"

      # this command can take some time - hence it should be called multiple times if necessary
      request_counter, response = 0, {}
      until request_counter >= 20 or response.has_key?('shardAdded')
        request_counter += 1

        begin
          response = run_command_on_local_router(command)
        rescue Exception => e
          puts "Error occured #{e}"
        end
        puts "Command #{request_counter} - #{response.inspect}"
        sleep 5
      end
    end

    def stop_instance
      kill_processes_from_list(proc_list('instance'))

      puts 'Removing this instance shard from db cluster'
      command = BSON::OrderedHash.new
      command['listShards'] = 1

      list_shards_results = run_command_on_local_router(command)

      if list_shards_results['ok'] == 1
        shard = list_shards_results['shards'].find { |x| x['host'] == "#{@host}:#{@config['db_instance_port']}" }

        if shard.nil?
          puts "Couldn't find shard with host set to #{@host}:#{@config['db_instance_port']} - #{list_shards_results['shards'].inspect}"
        else
          command = BSON::OrderedHash.new
          command['removeshard'] = shard['_id']

          request_counter, response = 0, {}
          until request_counter >= 20 or response['state'] == 'completed'
            request_counter += 1

            begin
              response = run_command_on_local_router(command)
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

      @information_service.send_request('deregister_db_instance', { server: @host, port: @config['db_instance_port'] })
    end

    def clear_instance
      puts "rm -rf #{DB_BIN_PATH}/#{@config['db_instance_dbpath']}/*"
      puts %x[rm -rf #{DB_BIN_PATH}/#{@config['db_instance_dbpath']}/*]
    end

    def start_instance_cmd
      log_append = File.exist?(@config['db_instance_logpath']) ? '--logappend' : ''

      ["cd #{DB_BIN_PATH}",
       "./mongod --shardsvr --bind_ip #{@host} --port #{@config['db_instance_port']} " +
           "--dbpath #{@config['db_instance_dbpath']} --logpath #{@config['db_instance_logpath']} " +
           "--cpu --quiet --rest --fork --nojournal #{log_append}"
      ].join(';')
    end

    def service_status(db_module = @db_module)
      if proc_list(db_module).empty?
        puts "Scalarm DB #{db_module} is not running"
        false
      else
        puts "Scalarm DB #{db_module} is running"
        true
      end
    end

    def start_config
      unless File.exist?(File.join(DB_BIN_PATH, @config['db_config_dbpath']))
        %x[mkdir -p #{File.join(DB_BIN_PATH, @config['db_config_dbpath'])}]
      end
      clear_config

      puts start_config_cmd
      puts %x[#{start_config_cmd}]

      @information_service.send_request('register_db_config_service', {server: @host, port: @config['db_config_port']})

      is_router_run = service_status('router')
      puts "Is router running: #{is_router_run}"
      puts "Starting router at: #{@host}:#{@config['db_config_port']}"

      start_router("#{@host}:#{@config['db_config_port']}")

      db = Mongo::Connection.new('localhost').db('admin')
      # retrieve already registered shards and add them to this service
      @information_service.send_request('db_instances').split('|||').map do |db_instance_string|
        puts "Db instance string: #{db_instance_string}"
        shard_host, shard_port = db_instance_string.split('---').first.split(':')

        command = BSON::OrderedHash.new
        command['addShard'] = "#{shard_host}:#{shard_port}"

        puts db.command(command).inspect
      end

      stop_router if not is_router_run
    end

    def stop_config
      kill_processes_from_list(proc_list('config'))

      @information_service.send_request('deregister_db_config_service', {server: @host, port: @config['db_config_port']})
    end

    def clear_config
      puts "rm -rf #{DB_BIN_PATH}/#{@config['db_config_dbpath']}/*"
      puts %x[rm -rf #{DB_BIN_PATH}/#{@config['db_config_dbpath']}/*]
    end

    # ./mongod --configsvr --dbpath /opt/scalarm_storage_manager/scalarm_db_data --port 28000 --logpath /opt/scalarm_storage_manager/log/scalarm_db.log --fork
    def start_config_cmd
      log_append = File.exist?(@config['db_config_logpath']) ? '--logappend' : ''

      ["cd #{DB_BIN_PATH}",
       "./mongod --configsvr --bind_ip #{@host} --port #{@config['db_config_port']} " +
           "--dbpath #{@config['db_config_dbpath']} --logpath #{@config['db_config_logpath']} " +
           "--fork --nojournal #{log_append}"
      ].join(';')
    end

    def start_router(config_service_url = nil)
      return if service_status('router')

      if config_service_url.nil?
        config_services = @information_service.send_request('db_config_services').split('|||')
        config_service_url = config_services.sample.split('---')[0] if config_services.size > 0
      end

      return if config_service_url.nil?

      puts start_router_cmd(config_service_url)
      puts %x[#{start_router_cmd(config_service_url)}]
    end

    def stop_router
      kill_processes_from_list(proc_list('router'))
    end

    # ./mongos --configdb eusas17.local:28000 --logpath /opt/scalarm_storage_manager/log/scalarm.log --fork
    def start_router_cmd(config_db_url = nil)
      log_append = File.exist?(@config['db_router_logpath']) ? '--logappend' : ''

      ["cd #{DB_BIN_PATH}",
       "./mongos --bind_ip #{@host} --port #{@config['db_router_port']} --configdb #{config_db_url} --logpath #{@config['db_router_logpath']} --fork #{log_append}"
      ].join(';')
    end

    def run_command_on_local_router(command)
      result = {}
      config_services = @information_service.send_request('db_config_services').split('|||')

      if config_services.size > 0
        # url to any config service
        config_service_url = config_services[0].split('---')[0]

        router_run = service_status('router')
        start_router(config_service_url)
        db = Mongo::Connection.new('localhost').db('admin')
        result = db.command(command)
        puts result.inspect
        stop_router if not router_run
      end

      result
    end

    def kill_processes_from_list(processes_list)
      processes_list.each do |process_line|
        pid = process_line.split(' ')[1]
        puts "kill -9 #{pid}"
        system("kill -9 #{pid}")
      end
    end

    def proc_list(service)
      proc_name = if service == 'router'
                    "./mongos --port #{@config['db_router_port']}"
                  elsif service == 'config'
                    "./mongod --configsvr .* --port #{@config['db_config_port']}"
                  elsif service == 'instance'
                    "./mongod .* --port #{@config['db_instance_port']}"
                  end

      out = %x[ps aux | grep "#{proc_name}"]
      #puts out
      out.split("\n").delete_if { |line| line.include? 'grep' }
    end

  end

end