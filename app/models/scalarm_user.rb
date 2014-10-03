# Attributes
# _id => auto generated user id
# dn => distinguished user name from certificate
# login => last CN attribute value from dn

class ScalarmUser < MongoActiveRecord

  def self.collection_name
    'scalarm_users'
  end

  def get_running_experiments
    Experiment.find_all_by_user_id(self.id).select do |experiment|
      experiment.is_running
    end
  end

  def get_historical_experiments
    Experiment.find_all_by_user_id(self.id).select do |experiment|
      experiment.is_running == false
    end
  end

  def get_simulation_scenarios
    Simulation.find_all_by_user_id(self.id)
  end

  def password=(pass)
    salt = [Array.new(6) { rand(256).chr }.join].pack('m').chomp
    self.password_salt, self.password_hash = salt, Digest::SHA256.hexdigest(pass + salt)
  end

  def self.authenticate_with_password(login, password)
    user = ScalarmUser.find_by_login(login)

    if user.nil? || user.password_salt.nil? || user.password_hash.nil?  || Digest::SHA256.hexdigest(password + user.password_salt) != user.password_hash
      raise 'Bad login or password'
    end

    user
  end

  def self.authenticate_with_certificate(dn)
    user = (ScalarmUser.find_by_dn(dn) or
        ScalarmUser.find_by_dn(ScalarmUser.browser_dn_to_plgoid_dn(dn)))

    if user.nil?
      raise "Authentication failed: user with DN = #{dn} not found"
    end

    user
  end

  # A hack to support PL-Grid OpenID returned DN's in database
  def self.browser_dn_to_plgoid_dn(dn)
    dn.split('/').slice(1..-1).reverse.join(',')
  end

end