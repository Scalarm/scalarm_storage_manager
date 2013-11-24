require 'yaml'

class LogBankController < ApplicationController
  before_filter :authenticate, :except => [ :status ]

  def status
    render inline: "Hello world from Scalarm LogBank, it's #{Time.now} at the server!\n"
  end

  def get_simulation_output
    experiment_id = params[:experiment_id]
    simulation_id = params[:simulation_id]
    mongo_log_bank = MongoLogBank.new(YAML.load_file("#{Rails.root}/config/scalarm.yml"))

    # just stream previously save binary data from the backend using included module
    file_object = mongo_log_bank.get_simulation_output(experiment_id, simulation_id)

    if file_object.nil?
      render inline: 'Required file not found', status: 404
    else
      response.headers['Content-Type'] = 'Application/octet-stream'
      response.headers['Content-Disposition'] = 'attachment; filename="experiment_' + experiment_id + '_simulation_' + simulation_id + '.tar.gz"'

      file_object.each do |data_chunk|
        response.stream.write data_chunk
      end

      response.stream.close
    end

  end

  def put_simulation_output
    experiment_id = params[:experiment_id]
    simulation_id = params[:simulation_id]
    mongo_log_bank = MongoLogBank.new(YAML.load_file("#{Rails.root}/config/scalarm.yml"))

    unless params[:file] && (tmpfile = params[:file].tempfile)
      render inline: 'No file provided', status: 400
    else
      mongo_log_bank.put_simulation_output(experiment_id, simulation_id, tmpfile)

      render inline: 'Upload completed'
    end
  end

  def delete_simulation_output
    experiment_id, simulation_id = params[:experiment_id], params[:simulation_id]
    mongo_log_bank = MongoLogBank.new(YAML.load_file("#{Rails.root}/config/scalarm.yml"))

    mongo_log_bank.delete_simulation_output(experiment_id, simulation_id)

    render inline: 'Delete completed'
  end

  def get_experiment_output
    experiment_id = params[:experiment_id]
    mongo_log_bank = MongoLogBank.new(YAML.load_file("#{Rails.root}/config/scalarm.yml"))

    %x[cd /tmp; rm -rf experiment_#{experiment_id} experiment_#{experiment_id}.zip]

    Dir.mkdir("/tmp/experiment_#{experiment_id}")
    %x[cd /tmp; zip experiment_#{experiment_id}.zip ./experiment_#{experiment_id}/]

    params[:start_id].to_i.upto(params[:to_id].to_i) do |simulation_id|
      # just stream previously save binary data from the backend using included module
      file_object = mongo_log_bank.get_simulation_output(experiment_id, simulation_id.to_s)
      next if file_object.nil?
      IO.write("/tmp/experiment_#{experiment_id}/simulation_#{simulation_id}.tar.gz", file_object.read.force_encoding('UTF-8'))

      %x[cd /tmp; zip -r experiment_#{experiment_id}.zip ./experiment_#{experiment_id}/; rm ./experiment_#{experiment_id}/*]
    end

    %x[cd /tmp; rm -rf experiment_#{experiment_id}]

    response.headers['Content-Type'] = 'Application/octet-stream'
    response.headers['Content-Disposition'] = 'attachment; filename="experiment_' + experiment_id + '.zip"'

    File.open("/tmp/experiment_#{experiment_id}.zip") do |f|
      until f.eof?
        response.stream.write f.read(2048)
      end
    end

    response.stream.close
  end

  def delete_experiment_output
    experiment_id = params[:experiment_id]
    mongo_log_bank = MongoLogBank.new(YAML.load_file("#{Rails.root}/config/scalarm.yml"))

    params[:start_id].to_i.upto(params[:to_id].to_i) do |simulation_id|
      #logger.info("DELETE experiment id: #{experiment_id}, simulation_id: #{simulation_id}")
      mongo_log_bank.delete_simulation_output(experiment_id, simulation_id.to_s)
    end

    render inline: 'DELETE experiment action completed'
  end

end
