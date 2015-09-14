require 'scalarm/service_core/initializers/mongo_active_record_initializer'

unless Rails.env.test?
  MongoActiveRecordInitializer.start(Utils.load_database_config,
                                     ignore_connection_failure: true)
end