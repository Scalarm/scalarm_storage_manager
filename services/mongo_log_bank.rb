require 'mongo'

module Scalarm

  # in a mongo database we should have to collections:
  # for actual data (gridfs) and for metedata (which object_id is related to a simulation output file)
  module MongoLogBank
    include Mongo

    @@binary_store = nil
    @@simulation_coll = nil

    def put_simulation_output(experiment_id, simulation_id, tmpfile)
      prepare_connection
      # put the given tmpfile in the mongodb specified in configuration
      output_file_id = @@binary_store.put(tmpfile)
      # store a document in another collection with obtained object_id
      simulation_output_doc = {
          experiment_id: experiment_id,
          simulation_id: simulation_id,
          output_file_id: output_file_id
      }

      @@simulation_coll.insert(simulation_output_doc)
    end

    def get_simulation_output(experiment_id, simulation_id)
      prepare_connection
      # retrieve the output file id for the given experiment_id and simulation_id
      simulation_output_doc = @@simulation_coll.find_one({ experiment_id: experiment_id, simulation_id: simulation_id })
      return nil if simulation_output_doc.nil?
      # get the actual file
      output_file_id = simulation_output_doc['output_file_id']
      @@binary_store.get(output_file_id)
    end

    def delete_simulation_output(experiment_id, simulation_id)
      prepare_connection
      # retrieve the output file id for the given experiment_id and simulation_id
      simulation_output_doc = @@simulation_coll.find_one({ experiment_id: experiment_id, simulation_id: simulation_id })
      return nil if simulation_output_doc.nil?
      # get the actual file
      output_file_id = simulation_output_doc['output_file_id']
      @@binary_store.delete(output_file_id)
      @@simulation_coll.remove({ experiment_id: experiment_id, simulation_id: simulation_id })
    end

    def prepare_connection
      return if not @@binary_store.nil?
      # initialize connection to mongodb
      @client = MongoClient.new(@config_yaml['mongo_host'], @config_yaml['mongo_port'])
      @db     = @client[@config_yaml['db_name']]
      @@binary_store = Mongo::Grid.new(@db)
      @@simulation_coll = @db[@config_yaml['binaries_collection_name']]
    end

  end

end
