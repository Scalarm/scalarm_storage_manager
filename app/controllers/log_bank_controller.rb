require 'zip/zip'
require 'zip/zipfilesystem'
require 'yaml'

class LogBankController < ApplicationController
  before_filter :authenticate, :except => [ :status, :get_simulation_output_size, :get_experiment_output_size, :get_simulation_stdout_size ]
  before_filter :load_log_bank, :except => [ :status ]
  before_filter :authorize_get, only: [ :get_simulation_output, :get_experiment_output, :get_simulation_stdout ]
  before_filter :authorize_put, only: [ :put_simulation_output, :put_simulation_stdout ]
  before_filter :authorize_delete, only: [ :delete_simulation_output, :delete_experiment_output, :delete_simulation_stdout ]

  @@experiment_size_threshold = 1024*1024*1024*300 # 300 MB

  def status
    render inline: "Hello world from Scalarm LogBank, it's #{Time.now} at the server!\n"
  end

  def get_simulation_output
    # just stream previously save binary data from the backend using included module
    file_object = @log_bank.get_simulation_output(@experiment_id, @simulation_id)

    if file_object.nil?
      render inline: 'Required file not found', status: 404
    else
      file_name = "experiment_#{@experiment_id}_simulation_#{@simulation_id}.tar.gz"
      response.headers['Content-Type'] = 'Application/octet-stream'
      response.headers['Content-Disposition'] = 'attachment; filename="' + file_name + '"'

      file_object.each do |data_chunk|
        response.stream.write data_chunk
      end

      response.stream.close
    end

  end

  def get_simulation_output_size
    file_object = @log_bank.get_simulation_output(@experiment_id, @simulation_id)

    if file_object.nil?
      render inline: 'Required file not found', status: 404
    else
      render inline: file_object.file_length.to_s
    end
  end

  def put_simulation_output
    unless params[:file] && (tmpfile = params[:file].tempfile)
      render inline: 'No file provided', status: 400
    else
      @log_bank.put_simulation_output(@experiment_id, @simulation_id, tmpfile)

      render inline: 'Upload completed'
    end
  end

  def delete_simulation_output
    @log_bank.delete_simulation_output(experiment_id, simulation_id)

    render inline: 'Delete completed'
  end

  def get_experiment_output
    experiment = Experiment.find_by_id(@experiment_id)

    output_size = 0
    1.to_i.upto(experiment.size) do |simulation_id|
      file_object = @log_bank.get_simulation_output(@experiment_id, simulation_id.to_s)
      output_size += file_object.file_length unless file_object.nil?
    end

    if output_size > @@experiment_size_threshold
      render inline: "Experiment size: #{output_size / (1024**3)} [MB] - it is too large. Please, download subsequent simulation results manually", status: 406
    else

        t = Tempfile.new("experiment_#{@experiment_id}")

        # Give the path of the temp file to the zip outputstream, it won't try to open it as an archive.
        Zip::ZipOutputStream.open(t.path) do |zos|
          1.to_i.upto(experiment.size) do |simulation_id|
            # just stream previously save binary data from the backend using included module
            file_object = @log_bank.get_simulation_output(@experiment_id, simulation_id.to_s)

            unless file_object.nil?
              # Create a new entry with some arbitrary name
              zos.put_next_entry("experiment_#{@experiment_id}/simulation_#{simulation_id}.tar.gz")
              # Add the contents of the file, don't read the stuff linewise if its binary, instead use direct IO
              zos.print file_object.read.force_encoding('UTF-8')
            end

            stdout_file_object = @log_bank.get_simulation_stdout(@experiment_id, simulation_id.to_s)
            unless stdout_file_object.nil?
              # Create a new entry with some arbitrary name
              zos.put_next_entry("experiment_#{@experiment_id}/simulation_#{simulation_id}_stdout.txt")
              # Add the contents of the file, don't read the stuff linewise if its binary, instead use direct IO
              zos.print stdout_file_object.read.force_encoding('UTF-8')
            end
          end
        end

        # End of the block  automatically closes the file.
        # Send it using the right mime type, with a download window and some nice file name.
        send_file t.path, type: 'application/zip', disposition: 'attachment', filename: "experiment_#{@experiment_id}.zip"
        # The temp file will be deleted some time...
        t.close
    end

  end

  def get_experiment_output_size
    output_size = 0
    experiment = Experiment.find_by_id(@experiment_id)

    1.to_i.upto(experiment.size) do |simulation_id|
      file_object = @log_bank.get_simulation_output(@experiment_id, simulation_id.to_s)
      output_size += file_object.file_length unless file_object.nil?
    end

    render inline: output_size.to_s
  end

  def delete_experiment_output
    experiment = Experiment.find_by_id(@experiment_id)
    1.to_i.upto(experiment.size) do |simulation_id|
      #logger.info("DELETE experiment id: #{experiment_id}, simulation_id: #{simulation_id}")
      @log_bank.delete_simulation_output(@experiment_id, simulation_id.to_s)
      @log_bank.delete_simulation_stdout(@experiment_id, simulation_id.to_s)
    end

    render inline: 'DELETE experiment action completed'
  end


  def get_simulation_stdout
    # just stream previously save binary data from the backend using included module
    file_object = @log_bank.get_simulation_stdout(@experiment_id, @simulation_id)

    if file_object.nil?
      render inline: 'Required file not found', status: 404
    else
      file_name = "experiment_#{@experiment_id}_simulation_#{@simulation_id}_stdout.txt"
      response.headers['Content-Type'] = 'text/plain'
      response.headers['Content-Disposition'] = 'attachment; filename="' + file_name + '"'

      file_object.each do |data_chunk|
        response.stream.write data_chunk
      end

      response.stream.close
    end

  end

  def get_simulation_stdout_size
    file_object = @log_bank.get_simulation_stdout(@experiment_id, @simulation_id)

    if file_object.nil?
      render inline: 'Required file not found', status: 404
    else
      render inline: file_object.file_length.to_s
    end
  end

  def put_simulation_stdout
    unless params[:file] && (tmpfile = params[:file].tempfile)
      render inline: 'No file provided', status: 400
    else
      @log_bank.put_simulation_stdout(@experiment_id, @simulation_id, tmpfile)

      render inline: 'Upload completed'
    end
  end

  def delete_simulation_stdout
    @log_bank.delete_simulation_stdout(@experiment_id, @simulation_id)

    render inline: 'Delete completed'
  end


  private

  def load_log_bank
    @log_bank = MongoLogBank.new(YAML.load_file("#{Rails.root}/config/scalarm.yml"))
    @experiment_id = params[:experiment_id]
    @simulation_id = params[:simulation_id]
  end

  # only the experiment owner or a person mentioned on the shared with experiment can get output
  def authorize_get
    if @current_user.nil? or @experiment_id.nil?
      render inline: '', status: 404
      return 
    end
      
    experiment = Experiment.find_by_id(@experiment_id)
    unless experiment.owned_by?(@current_user) or experiment.shared_with?(@current_user)
      render inline: '', status: 401      
    end
  end

  # all types of Scalarm users (the owner, a user on the shared with list, and the Simulation Manager can put data)
  def authorize_put
    if @experiment_id.nil? or (@current_user.nil? and @sm_user.nil?)
      Rails.logger.debug('Something is wrong')
      render inline: '', status: 404
      return 
    end

    experiment = Experiment.find_by_id(@experiment_id)

    if not @current_user.nil?

      unless experiment.owned_by?(@current_user) or experiment.shared_with?(@current_user)
        render inline: '', status: 401
      end

    elsif not @sm_user.nil?
      Rails.logger.debug('We are on the right track')

      unless @sm_user.executes?(experiment)
        Rails.logger.debug('But something went wrong')
        render inline: '', status: 401
      end

    else

      render inline: '', status: 401

    end
  end

  # only the experiment owner can delete data
  def authorize_delete
    if @current_user.nil? or @experiment_id.nil?
      render inline: '', status: 404
      return
    end
      
    experiment = Experiment.find_by_id(@experiment_id)
    unless experiment.owned_by?(@current_user) 
      render inline: '', status: 401
    end
  end

end
