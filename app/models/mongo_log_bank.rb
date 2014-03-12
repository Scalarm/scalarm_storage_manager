require 'mongo'

class MongoLogBank
  include Mongo

  def initialize(config)
    @binary_store = nil
    @simulation_coll = nil
    @config_yaml = config

    prepare_connection
  end

  # put the given tmpfile in the mongodb specified in configuration
  def put_simulation_output(experiment_id, simulation_id, tmpfile)
    output_file_id = @binary_store.put(tmpfile)
    # store a document in another collection with obtained object_id
    simulation_output_doc = {
        experiment_id: experiment_id,
        simulation_id: simulation_id,
        output_file_id: output_file_id
    }

    @simulation_coll.insert(simulation_output_doc)
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
        output_file_id: output_file_id
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
    @binary_store = Mongo::Grid.new(@db)
    @simulation_coll = @db[@config_yaml['binaries_collection_name']]
  end
end