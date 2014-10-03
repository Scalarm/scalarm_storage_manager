# Attributes:
#_id: id
#experiment_id: ObjectId
#simulation_id: ObjectId - when this record denotes binary results of a simulation run this is simulation_id
#simulation_stdout: ObjectId - when this record denotes stdout of a simulation run this is simulation_id
#output_file_id: ObjectId - id of a file stored in mongodb GridFS
#file_size: int - size in [B] of a stored file

class SimulationOutputRecord < MongoActiveRecord

  @@ids_autoconvert = false

  def self.collection_name
    @@config['binaries_collection_name']
  end

  def file_object
    self.output_file_id.nil? ? nil : @@binary_store.get(self.output_file_id)
  end

  def file_object_name
    if (not self.simulation_id.nil?)
      "simulation_#{self.simulation_id}.tar.gz"
    elsif (not self.simulation_stdout.nil?)
      "simulation_#{self.simulation_stdout}_stdout.txt"
    else
      nil
    end
  end

  # binary store initializing
  @@config = YAML.load_file("#{Rails.root}/config/scalarm.yml")
  @@binary_store = Mongo::Grid.new(SimulationOutputRecord.get_database(@@config['db_name']))
end