require 'zip/zip'
require 'zip/zipfilesystem'
require 'yaml'

class LogBankController < ApplicationController
  before_filter :authenticate, :except => [ :status ]
  before_filter :load_log_bank, :except => [ :status ]

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
    t = Tempfile.new("experiment_#{@experiment_id}")

    # Give the path of the temp file to the zip outputstream, it won't try to open it as an archive.
    Zip::ZipOutputStream.open(t.path) do |zos|
      params[:start_id].to_i.upto(params[:to_id].to_i) do |simulation_id|
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
          zos.put_next_entry("experiment_#{@experiment_id}/simulation_#{simulation_id}.tar.gz")
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

    # %x[cd /tmp; rm -rf experiment_#{@experiment_id} experiment_#{@experiment_id}.zip]

    # Dir.mkdir("/tmp/experiment_#{@experiment_id}")
    # %x[cd /tmp; zip experiment_#{@experiment_id}.zip ./experiment_#{@experiment_id}/]

    # params[:start_id].to_i.upto(params[:to_id].to_i) do |simulation_id|
    #   # just stream previously save binary data from the backend using included module
    #   file_object = @log_bank.get_simulation_output(@experiment_id, simulation_id.to_s)
    #   unless file_object.nil?
    #     IO.write("/tmp/experiment_#{@experiment_id}/simulation_#{simulation_id}.tar.gz", file_object.read.force_encoding('UTF-8'))
    #   end

    #   stdout_file_object = @log_bank.get_simulation_stdout(@experiment_id, simulation_id.to_s)
    #   unless stdout_file_object.nil?
    #     IO.write("/tmp/experiment_#{@experiment_id}/simulation_#{simulation_id}_stdout.txt", stdout_file_object.read.force_encoding('UTF-8'))
    #   end

    #   %x[cd /tmp; zip -r experiment_#{@experiment_id}.zip ./experiment_#{@experiment_id}/; rm ./experiment_#{@experiment_id}/*]
    # end

    # %x[cd /tmp; rm -rf experiment_#{@experiment_id}]

    # response.headers['Content-Type'] = 'Application/octet-stream'
    # response.headers['Content-Disposition'] = 'attachment; filename="experiment_' + @experiment_id + '.zip"'

    # File.open("/tmp/experiment_#{@experiment_id}.zip") do |f|
    #   until f.eof?
    #     response.stream.write f.read(2048)
    #   end
    # end

    # response.stream.close
  end

  def delete_experiment_output
    params[:start_id].to_i.upto(params[:to_id].to_i) do |simulation_id|
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

end
