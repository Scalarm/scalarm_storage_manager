# Attributes
# sm_uuid => string - uuid which identifies a simulation manager - also can be used as user
# password => password of the attached simulation manager
# experiment_id => id of an experiment executed by this Simulation Manager

class SimulationManagerTempPassword < MongoActiveRecord

  def self.collection_name
    'simulation_manager_temp_passwords'
  end

  def self.create_new_password_for(sm_uuid, experiment_id)
    password = SecureRandom.base64
    temp_pass = SimulationManagerTempPassword.new({'sm_uuid' => sm_uuid,
                                                   'password' => password,
                                                   'experiment_id' => experiment_id})

    temp_pass.save
    temp_pass
  end

  def executes?(experiment)
    experiment.experiment_id == self.experiment_id
  end

end
