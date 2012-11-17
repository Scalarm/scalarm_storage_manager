require "mongo"
require "bson"
require_relative "information_service"

class ScalarmDb

  def initialize(config, service_param)
    if config.nil? or not ["router", "config", "instance"].include?(service_param)
      raise Exception.new("Bad argument - should be (router,configsrv,new_instance) - or empty config")
    end

    @config = config
    @service_param = service_param

    @host = ""
    UDPSocket.open { |s| s.connect('64.233.187.99', 1); @host = s.addr.last }

    @information_service = InformationService.new(@config)
  end

  def execute(command)
    if not ["start", "stop", "status", "clear"].include?(command)
      raise Exception.new("Bad command - should be (start|stop|status)")
    end

    puts "ScalarmDb executes #{command} for #{@service_param}"

    if command == "status"
      service_status(@service_param)
    else
      self.send("#{command}_#{@service_param}")
    end
  end

  def run_command_on_local_router(command)
    config_services = @information_service.send_request("db_config_services").split("|||")
    if config_services.size > 0
      # url to any config service
      config_service_url = config_services[0].split("---")[0]

      router_run = service_status("router")
      start_router(config_service_url) if not router_run
      db = Mongo::Connection.new("localhost").db("admin")
      puts db.command(command).inspect
      stop_router if not router_run
    end
  end

  def kill_processes_from_list(processes_list)
    processes_list.each do |process_line|
      pid = process_line.split(" ")[1]
      puts "kill -9 #{pid}"
      system("kill -9 #{pid}")
    end
  end

  def service_status(service)
    if proc_list(service).empty?
      puts "Scalarm DB #{service} is not running"
      false
    else
      puts "Scalarm DB #{service} is running"
      true
    end
  end

  def start_instance
    puts start_instance_cmd
    puts %x[#{start_instance_cmd}]

    # register in information service
    @information_service.send_request("register_db_instance", {"server" => @host, "port" => @config["db_instance_port"]})
    # adding shard
    puts "Adding shard"
    2.times do
      command = BSON::OrderedHash.new
      command["addShard"] = "#{@host}:#{@config["db_instance_port"]}"
      command["name"] = "#{@host}"

      begin
        run_command_on_local_router(command)
      rescue Exception => e
        puts "Error occured #{e}"
      end
    end
  end

  def clear_instance
    puts "rm -rf ./mongodb-linux-x86_64-2.2.1/bin/#{@config["db_instance_dbpath"]}/*"
    puts %x[rm -rf ./mongodb-linux-x86_64-2.2.1/bin/#{@config["db_instance_dbpath"]}/*]
  end

  def clear_config
    puts "rm -rf ./mongodb-linux-x86_64-2.2.1/bin/#{@config["db_configsrv_dbpath"]}/*"
    puts %x[rm -rf ./mongodb-linux-x86_64-2.2.1/bin/#{@config["db_configsrv_dbpath"]}/*]
  end

  def stop_instance
    kill_processes_from_list(proc_list("instance"))

    # removing shard
    puts "Removing shard"
    2.times() do
      command = BSON::OrderedHash.new
      command["removeshard"] = "#{@host}"

      run_command_on_local_router(command)
    end

    @information_service.send_request("deregister_db_instance", {"server" => @host, "port" => @config["db_instance_port"]})
  end

  def start_instance_cmd
    log_append = File.exist?(@config["db_instance_logpath"]) ? "--logappend" : ""
    ["cd ./mongodb-linux-x86_64-2.2.1/bin",
      "./mongod --bind_ip #{@host} --port #{@config["db_instance_port"]} " +
      "--dbpath #{@config["db_instance_dbpath"]} --logpath #{@config["db_instance_logpath"]} " +
      "--cpu --quiet --rest --fork #{log_append}"
    ].join(";")
  end

  def start_config
    puts start_config_cmd
    puts %x[#{start_config_cmd}]

    @information_service.send_request("register_db_config_service", {"server" => @host, "port" => @config["db_configsrv_port"]})

    is_router_run = service_status("router")
    start_router("#{@host}:#{@config["db_configsrv_port"]}") if not is_router_run

    db = Mongo::Connection.new("localhost").db("admin")
    # adding shards
    @information_service.send_request("db_instances").split("|||").map do |db_instance_string|
      puts "Db instance string: #{db_instance_string}"
      shard_host, shard_port = db_instance_string.split("---").first.split(":")
      ##db.runCommand( { addShard: mongodb0.example.net, name: "mongodb0" } )
      command = BSON::OrderedHash.new
      command["addShard"] = "#{shard_host}:#{shard_port}"
      command["name"] = "#{shard_host}"

      puts db.command(command).inspect
    end

    stop_router if not is_router_run
  end

  def stop_config
    kill_processes_from_list(proc_list("config"))

    @information_service.send_request("deregister_db_config_service", {"server" => @host, "port" => @config["db_configsrv_port"]})
  end

  # ./mongod --configsvr --dbpath /opt/scalarm_storage_manager/scalarm_db_data --port 28000 --logpath /opt/scalarm_storage_manager/log/scalarm_db.log --fork
  def start_config_cmd
    log_append = File.exist?(@config["db_instance_logpath"]) ? "--logappend" : ""
    ["cd ./mongodb-linux-x86_64-2.2.1/bin",
     "./mongod --configsvr --bind_ip #{@host} --port #{@config["db_configsrv_port"]} " +
         "--dbpath #{@config["db_configsrv_dbpath"]} --logpath #{@config["db_configsrv_logpath"]} " +
         "--fork #{log_append}"
    ].join(";")
  end

  def start_router(config_service_url = nil)
    return if service_status("router")

    if config_service_url.nil?
      config_services = @information_service.send_request("db_config_services").split("|||")
      config_service_url = config_services[0].split("---")[0] if config_services.size > 0
    end

    return if config_service_url.nil?

    puts start_router_cmd(config_service_url)
    puts %x[#{start_router_cmd(config_service_url)}]
  end

  def stop_router
    kill_processes_from_list(proc_list("router"))
  end

  # ./mongos --configdb eusas17.local:28000 --logpath /opt/scalarm_storage_manager/log/scalarm.log --fork
  def start_router_cmd(config_db_url = nil)
    log_append = File.exist?(@config["db_router_logpath"]) ? "--logappend" : ""
    ["cd ./mongodb-linux-x86_64-2.2.1/bin",
     "./mongos --configdb #{config_db_url} --logpath #{@config["db_router_logpath"]} --fork #{log_append}"
    ].join(";")
  end

  def proc_list(service)
    proc_name = if service == "router"
                  "./mongos"
                elsif service == "config"
                  "./mongod --configsvr"
                elsif service == "instance"
                  "./mongod.*--port #{@config["db_instance_port"]}"
                end

    out = %x[ps aux | grep "#{proc_name}"]
    out.split("\n").delete_if { |line| line.include? "grep" }
  end

end