require "rubygems"
require "sinatra"
require "data_mapper"
require "haml"
require "socket"

module Cyfronet

  class DataCloud < Sinatra::Base

    use Rack::Auth::Basic, "Restricted Area" do |username, password|
      [username, password] == ['eusas', 'pr4tt7_sim0']
    end

    prefix = "./public/cloud_data"

    get '/' do
      "Hello world, it's #{Time.now} at the server!\n"
    end

    get "/upload" do
      haml :upload
    end

    post '/upload' do
      Cyfronet::log("I am in #{`pwd`}")
      upload_start = Time.now

      path = params['path']
      dir_name = File.dirname(path)

      Cyfronet::log("Uploding file to PATH started: #{path} --- #{path.start_with?(prefix)} --- #{not path.include?("..")}")

      if path.start_with?(prefix) and (not path.include?(".."))
        FileUtils.mkdir_p(dir_name)

        File.open(path, "w") do |f|
          f.write(params['myfile'][:tempfile].read)
        end

        Cyfronet::log("FILE #{path} UPLOADED IN #{(Time.now - upload_start)} [sec]")

        return "The file was successfully uploaded!"
      else
        return "Wrong path - has to be started with #{prefix} and can not include '..'"
      end
    end

    post '/upload-archive' do
      upload_start = Time.now

      path = params['path']
      dir_name = File.dirname(File.dirname(path))

      Cyfronet::log("Uploding file to PATH started: #{path} --- #{path.start_with?(prefix)} --- #{not path.include?("..")}")

      if path.start_with?(prefix) and (not path.include?(".."))
        uid = Time.now.to_i
        temp_dir = File.join(dir_name, "tmp-logs-#{uid}")

        save_and_unpack_file_in(temp_dir)
        move_logs_from_temp(temp_dir, dir_name)

        Cyfronet::log("FILE #{path} UPLOADED ARCHIVE IN #{(Time.now - upload_start)} [sec]")

        return "The file was successfully uploaded!"
      else
        return "Wrong path - has to be started with #{prefix} and can not include '..'"
      end
    end

    post '/multiupload' do
      upload_start = Time.now
      path = params['path']

      Cyfronet::log("Uploding multi file to PATH started: #{path} --- #{path.start_with?(prefix)} --- #{not path.include?("..")}")

      if path.start_with?(prefix) and (not path.include?(".."))
        uid = Time.now.to_i
        temp_dir = File.join(path, "tmp-logs-#{uid}")

        save_and_unpack_file_in(temp_dir)
        move_logs_from_temp(temp_dir, path)

        Cyfronet::log("FILE #{path} UPLOADED ARCHIVE IN #{(Time.now - upload_start)} [sec]")

        return "The file was successfully uploaded!"
      else
        return "Wrong path - has to be started with #{prefix} and can not include '..'"
      end
    end

    private

    def save_and_unpack_file_in(dir_name)
      FileUtils.mkdir_p(dir_name)

      File.open(File.join(dir_name, "logs.tar.gz"), "w") do |f|
        f.write(params['myfile'][:tempfile].read)
      end

      cmd = ["cd #{dir_name}", "tar xzvf logs.tar.gz", "rm logs.tar.gz"]
      Cyfronet::log(`#{cmd.join("; ")}`)
    end

    def move_logs_from_temp(temp_dir, path)
      Dir.foreach(temp_dir) do |item|
        next if item == '.' or item == '..'
        conf_id, log_file_name = item.split("_")
        Cyfronet::log("Conf id = #{conf_id} --- Log name = #{log_file_name}")
        Cyfronet::log(`mv #{File.join(temp_dir, item)} #{File.join(path, conf_id, log_file_name)}`)
      end

      Cyfronet::log(`rm -rf #{temp_dir}`)
    end

  end

  def self.log(msg)
    puts("#{Time.now.strftime("%F %T")} - #{msg}")
    $stdout.flush
  end

end
    
