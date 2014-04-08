# This is a copy-paste version of the monitoring probe class from the Experiment Manager
# with one exception in the 'send_measurement' method

class MonitoringProbe
  TIME_FORMAT = "%Y-%m-%d %H:%M:%S"

  def initialize
    log('Starting')
    @config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))['monitoring']
    @db_name = @config['db_name']
    @db = MongoActiveRecord.get_database(@db_name)
    @interval = @config['interval'].to_i
    @metrics = @config['metrics'].split(':')

    @host = ""
    UDPSocket.open { |s| s.connect('64.233.187.99', 1); @host = s.addr.last }
    @host.gsub!("\.", "_")
  end

  def start_monitoring
    slog('monitoring_probe', "lock file exists? #{File.exists?(lock_file_path)}")
    Thread.new do

      slog('monitoring_probe', "lock file exists? #{File.exists?(lock_file_path)}")

      if File.exists?(lock_file_path)
        log('the lock file exists')
      else
        log('there is no lock file so we create one')
        IO.write(lock_file_path, Thread.current.object_id)

        at_exit{ File.delete(lock_file_path) if File.exist?(lock_file_path) }

        while true
          monitor
          sleep(@interval)
        end
      end

    end
  end

  def lock_file_path
    File.join Rails.root, 'tmp', 'em_monitoring.lock'
  end

  def log(message, log_level = 'debug')
    Rails.logger.send(log_level, "[monitoring-probe][#{Thread.current.object_id}] #{message}")
  end

  def monitor
    measurements = @metrics.reduce([]) do |acc, metric_type|
      begin
        acc + self.send("monitor_#{metric_type}")
      rescue Exception => e
        log("An exception occurred during monitoring of #{metric_type}", 'error')
        acc
      end
    end

    send_measurements(measurements)
  end

  def send_measurements(measurements)
    last_inserted_values = {}

    measurements.each do |measurement_table|
      table_name = "#{@host}.#{measurement_table[0]}"
      table = @db[table_name]

      last_value = nil
      if not last_inserted_values.has_key?(table_name) or last_inserted_values[table_name].nil?
        last_value = table.find_one({}, { :sort => [ [ "date", "desc" ] ]})
      else
        last_value = last_inserted_values[table_name]
      end

      doc = {"date" => measurement_table[1], "value" => measurement_table[2]}

      if not last_value.nil?

        last_date = last_value["date"]
        current_date = doc["date"]

        next if last_date > current_date
      end

      puts "Table: #{table_name}, Measurement of #{measurement_table[0]} : #{doc}"
      table.insert(doc)
      last_inserted_values[table_name] = doc
    end

  end

  def send_measurement(controller, action, processing_time)
    table_name = "#{@host}.StorageManager___#{controller}___#{action}"
    doc = { date: Time.now, value: processing_time }
    @db[table_name].insert(doc)
  end

  # monitors percantage utilization of the CPU [%]
  def monitor_cpu
    cpu_idle = if RUBY_PLATFORM.include?('darwin')
                 iostat_out = `iostat -c 3`
                 iostat_out = iostat_out.split("\n")[1..-1]
                 idle_index = iostat_out[0].split.index('id')
                 iostat_out[-1].split[idle_index].to_f
              else
                 mpstat_out = `mpstat 1 1`
                 mpstat_lines = mpstat_out.split("\n")
                 cpu_util_values = mpstat_lines[-1].split
                 cpu_util_values[-1].to_f
              end

    cpu_util = 100.0 - cpu_idle

    [ [ 'System___NULL___CPU', Time.now, cpu_util.to_i.to_s] ]
  end

  # monitoring free memory in the system [MB]
  def monitor_memory
    free_mem = if RUBY_PLATFORM.include?('darwin')
            mem_lines = `top -l 1 | head -n 10 | grep PhysMem`
            mem_line = mem_lines.split("\n")[0].split(',')[-1].split('unused').first.strip
            mem_line[0...-1]
          else
            mem_lines = `free -m`
            mem_line = mem_lines.split("\n")[1].split
            mem_line[3]
          end

    [ [ "System___NULL___Mem", Time.now, free_mem ] ]
  end
  
  ## monitors various metric related to block devices utilization
  def monitor_storage
    storage_measurements = {}
    # get 5 measurements of iostat - the first one is irrelevant
    iostat_out = `iostat -d -m -x 1 5`
    iostat_out_lines = iostat_out.split("\n")
    # analyze each line
    iostat_out_lines.each_with_index do |iostat_out_line, i|
      # line with Device at starts means new a new measurement
      if iostat_out_line.start_with?("Device:")
        storage_metric_names = iostat_out_line.split(" ")
        # get measurements for two first devices
        1.upto(2) do |k|
          if not iostat_out_lines[i+k].nil?
            storage_metric_values = iostat_out_lines[i+k].split(" ")
            device_name = storage_metric_values[storage_metric_names.index("Device:")]
            next if device_name.nil? || device_name.empty?
            puts "Device name -#{device_name}- -#{device_name.nil? || device_name.empty?}-"

            puts storage_metric_names.join(", ")
            ["rMB/s", "wMB/s", "r/s", "w/s", "await"].each do |system_storage_metric|
              storage_metric_name = "Storage___#{device_name}___#{system_storage_metric.gsub("/", "_")}"
              # insert metric measurement structure
              storage_measurements[storage_metric_name] = [] if not storage_measurements.has_key? storage_metric_name
              # insert metric measurement value
              storage_measurements[storage_metric_name] << storage_metric_values[storage_metric_names.index(system_storage_metric)]
            end
          end
        end
      end
    end

    storage_metrics = []
    # calculate avg values
    storage_measurements.each do |metric_name, measurements|
      puts measurements
      avg_value = measurements[1..-1].reduce(0.0){|sum, x| sum += x.to_f }
      avg_value /= measurements.size - 1
      storage_metrics << [metric_name, Time.now.strftime("%Y-%m-%d %H:%M:%S"), avg_value]
    end

    storage_metrics
  end

end
