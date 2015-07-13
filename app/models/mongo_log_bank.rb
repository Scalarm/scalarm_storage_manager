require 'mongo'

##
# TODO: possible refactor, see below comment
# This class uses Mongo on it's own - consider extending
# MongoActiveRecord from Scalarm::ServiceCore to support
# binary storage and multiple databases (maybe MongoClient wrapper...)
class MongoLogBank
  include Mongo

  def initialize(config)
    @binary_store = nil
    @simulation_coll = nil
    @config_yaml = config

    prepare_connection
  end

  def get_file_object(file_object_id)
    @binary_store.get(file_object_id)
  end

  def get_output_files(experiment_id)
    @simulation_coll.find({experiment_id: experiment_id}).to_a
  end

  # put the given tmpfile in the mongodb specified in configuration
  def put_simulation_output(experiment_id, simulation_id, tmpfile)
    output_file_id = @binary_store.put(tmpfile)
    # store a document in another collection with obtained object_id
    simulation_output_doc = {
        experiment_id: experiment_id,
        simulation_id: simulation_id,
        output_file_id: output_file_id,
        file_size: tmpfile.length
    }

    @simulation_coll.insert(simulation_output_doc)
  end

  def get_experiment_output_size(experiment_id)
    experiment_output_size = 0

    @simulation_coll.find({experiment_id: experiment_id}, {fields: %w(output_file_id file_size)}).each do |simulation_doc|
      if simulation_doc.include?('file_size')
        experiment_output_size += simulation_doc['file_size']
      else
        output_file_id = simulation_doc['output_file_id']
        output_file = @binary_store.get(output_file_id)
        experiment_output_size += output_file.file_length unless output_file.nil?
      end
    end

    experiment_output_size
  end

  # retrieve the output file id for the given experiment_id and simulation_id
  def get_simulation_output(experiment_id, simulation_id)
    simulation_output_doc = @simulation_coll.find_one({experiment_id: experiment_id, simulation_id: simulation_id})
    return nil if simulation_output_doc.nil?
    # get the actual file
    output_file_id = simulation_output_doc['output_file_id']
    @binary_store.get(output_file_id)
  end

      # retrieve the output file id for the given experiment_id and simulation_id
  def delete_simulation_output(experiment_id, simulation_id)
    simulation_output_doc = @simulation_coll.find_one({experiment_id: experiment_id, simulation_id: simulation_id})
    return nil if simulation_output_doc.nil?
    # get the actual file
    output_file_id = simulation_output_doc['output_file_id']
    @binary_store.delete(output_file_id)
    @simulation_coll.remove({experiment_id: experiment_id, simulation_id: simulation_id})
  end

  # put the given tmpfile in the mongodb specified in configuration
  def put_simulation_stdout(experiment_id, simulation_id, tmpfile)
    output_file_id = @binary_store.put(tmpfile)
    # store a document in another collection with obtained object_id
    simulation_output_doc = {
        experiment_id: experiment_id,
        simulation_stdout: simulation_id,
        output_file_id: output_file_id,
        file_size: tmpfile.length
    }

    @simulation_coll.insert(simulation_output_doc)
  end

  # retrieve the output file id for the given experiment_id and simulation_id
  def get_simulation_stdout(experiment_id, simulation_id)
    simulation_output_doc = @simulation_coll.find_one({experiment_id: experiment_id, simulation_stdout: simulation_id})
    return nil if simulation_output_doc.nil?
    # get the actual file
    output_file_id = simulation_output_doc['output_file_id']
    @binary_store.get(output_file_id)
  end

      # retrieve the output file id for the given experiment_id and simulation_id
  def delete_simulation_stdout(experiment_id, simulation_id)
    simulation_output_doc = @simulation_coll.find_one({experiment_id: experiment_id, simulation_stdout: simulation_id})
    return nil if simulation_output_doc.nil?
    # get the actual file
    output_file_id = simulation_output_doc['output_file_id']
    @binary_store.delete(output_file_id)
    @simulation_coll.remove({experiment_id: experiment_id, simulation_stdout: simulation_id})
  end

  private

  def prepare_connection
    return if not @binary_store.nil?
    # initialize connection to mongodb
    @client = MongoClient.new(@config_yaml['mongo_host'], @config_yaml['mongo_port'])
    @db = @client[@config_yaml['db_name']]
    username = @config_yaml['auth_username']
    password = @config_yaml['auth_password']
    @db.authenticate(username, password) if username and password
    @binary_store = Mongo::Grid.new(@db)
    @simulation_coll = @db[@config_yaml['binaries_collection_name']]
  end
end