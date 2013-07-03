require_relative 'mongo_active_record'

# Attributes
# _id => auto generated user id
# dn => distinguished user name from certificate
# login => last CN attribute value from dn
# password => optionally encrypted password

class ScalarmUser < MongoActiveRecord

  def self.collection_name
    'scalarm_users'
  end

end