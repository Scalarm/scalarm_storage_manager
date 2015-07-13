# Attributes:
#_id: id
#experiment_id: ObjectId
#simulation_id: ObjectId - when this record denotes binary results of a simulation run this is simulation_id
#simulation_stdout: ObjectId - when this record denotes stdout of a simulation run this is simulation_id
#output_file_id: ObjectId - id of a file stored in mongodb GridFS
#file_size: int - size in [B] of a stored file

require 'scalarm/database/core/mongo_active_record'

class SimulationOutputRecord < Scalarm::Database::MongoActiveRecord
  # binary store initializing
  @@config = Utils.load_database_config
  @@binary_store = Mongo::Grid.new(SimulationOutputRecord.get_database(@@config['db_name']))

  use_collection @@config['binaries_collection_name']
  disable_ids_auto_convert!

  def file_object
    self.output_file_id.nil? ? nil : @@binary_store.get(self.output_file_id)
  end

  def file_object_name
    if not self.simulation_id.nil?
      "simulation_#{self.simulation_id}.tar.gz"
    elsif not self.simulation_stdout.nil?
      "simulation_#{self.simulation_stdout}_stdout.txt"
    else
      nil
    end
  end
end