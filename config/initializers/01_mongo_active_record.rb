require 'mongo_active_record'

MongoActiveRecord.connection_init(YAML.load_file("#{Rails.root}/config/scalarm.yml"))