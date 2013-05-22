require 'sinatra'
require 'yaml'
require 'rack'

require_relative 'mongo_log_bank'
require_relative '../model/information_service'

# TODO how to handle different implementations of log banks depending on passed configuration ?
module Scalarm

  class LogBankService < Sinatra::Base
    include Scalarm::MongoLogBank

    use Rack::Auth::Basic, 'Restricted Area' do |username, password|
      # TODO this should use open_id ?
      [username, password] == %w(scalarm change.NOW)
    end

    configure do
      # Logging configuration
      enable :logging

      file = File.new("#{settings.root}/../log/#{settings.environment}.log", 'a+')
      file.sync = true
      use Rack::CommonLogger, file

      set :config_yaml, YAML.load_file("#{settings.root}/../etc/log_bank.yml")
    end

    before do
      @config_yaml = settings.config_yaml
    end

    get '/status' do
      logger.info 'Executing default action'

      "Hello world from Scalarm LogBank, it's #{Time.now} at the server!\n"
    end

    put '/experiment/:experiment_id/simulation/:simulation_id' do
      logger.info 'Executing put simulation output action'
      # here we should have binary data in our request
      # put this data in the log bank using included module
      upload_start = Time.now
      experiment_id, simulation_id = params[:experiment_id], params[:simulation_id]

      logger.info "Storing binaries for Experiment #{experiment_id} and Simulation #{simulation_id}"

      unless params[:file] && (tmpfile = params[:file][:tempfile])
        [ 400, 'No file provided' ]
      else
        put_simulation_output(experiment_id, simulation_id, tmpfile)
        [ 200, 'Upload complete' ]
      end

      logger.info "Request handled in #{Time.now - upload_start} [s]"
    end

    get '/experiment/:experiment_id/simulation/:simulation_id' do
      logger.info 'Executing get simulation output action'
      experiment_id, simulation_id = params[:experiment_id], params[:simulation_id]
      # just stream previously save binary data from the backend using included module
      file_object = get_simulation_output(experiment_id, simulation_id)

      if file_object.nil?
        [ 404, 'Required file not found' ]
      else
        headers['Content-Type'] = 'Application/octet-stream'
        stream do |out|
          file_object.each do |data_chunk|
            out << data_chunk
          end
        end
      end
    end

    delete '/experiment/:experiment_id/simulation/:simulation_id' do
      logger.info 'Executing delete simulation output action'
      experiment_id, simulation_id = params[:experiment_id], params[:simulation_id]

      delete_simulation_output(experiment_id, simulation_id)
    end

  end

  def self.start_log_bank(host, port, pid_file, information_service)
    if File.exist?(pid_file)
      # TODO all logging should be to a file
      puts 'Scalarm LogBank is already running on the given port'
      exit(1)
    else
      # forking a sinatra web app
      pid = fork do
        app = Scalarm::LogBankService
        handler = Rack::Handler::Thin
        handler.run(app, :Port => port) do |_|
          puts "URL of the started Scalarm LogBank instance is: #{host}:#{port}"
          # this instance should be registered in the information service
          information_service.register_log_bank(host, port)
        end
      end
      # storing pid in a file and deteching the process
      File.open(pid_file, 'w') { |file| file.puts pid }
      Process.detach(pid)
      # TODO do we need to start a mongodb router here ?
    end
  end

  def self.stop_log_bank(host, port, pid_file, information_service)
    if File.exist?(pid_file)
      # deregister this instance from the information service
      information_service.deregister_log_bank(host, port)
      # stop the actual OS process
      pid = nil
      File.open(pid_file, 'r') { |file| pid = file.gets.to_i }
      File.delete(pid_file)
      puts "Killing process with #{pid} PID"
      Process.kill('TERM', pid)
      puts 'LongBank killed'
    else
      puts 'Is an instance of Scalarm LogBank really running on the given port? There is no pid file.'
      exit(1)
    end
  end

end
