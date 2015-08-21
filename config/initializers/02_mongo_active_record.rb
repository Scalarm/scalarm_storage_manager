require 'scalarm/service_core/initializers/mongo_active_record_initializer'

unless Rails.env.test?
  MongoActiveRecordInitializer.start(Utils.load_database_config,
                                     ignore_connection_failure: true)
end


unless Rails.env.test?
  require 'scalarm/database/core/mongo_active_record'
  require 'scalarm/database/logger'
  require 'scalarm/service_core/logger'

  # class initizalization
  # config moved to secrets.yml
  config = Utils.load_database_config

  # TODO move config to secrets.yml?
  #config = Rails.application.secrets.database

  if config.nil?
    slog('mongo_active_record', 'No database configuration, using defaults')
    config = {}

    config['db_name'] = 'scalarm_db'
    config['db_secret_key'] = 'QjqjFK}7|Xw8DDMUP-O$yp'
  end

  db_key = Digest::SHA256.hexdigest(config['db_secret_key'] || 'QjqjFK}7|Xw8DDMUP-O$yp')
  Scalarm::Database::MongoActiveRecord.set_encryption_key(db_key)

  Scalarm::Database::Logger.register(Rails.logger)
  Scalarm::ServiceCore::Logger.set_logger(Rails.logger)

  # by default, try to connect to local mongodb
  # TODO: connect to local mongodb only if list of db_routers is empty
  slog('mongo_active_record', 'Trying to connect to localhost')

  begin
    Scalarm::Database::MongoActiveRecord.connection_init('localhost', config['db_name'],
                                                         username: config['auth_username'],
                                                         password: config['auth_password']
    )
  rescue Mongo::ConnectionFailure
    slog('mongo_active_record', 'Cannot connect to local mongodb - fetching mongodb adresses from IS')
    information_service = InformationService.instance
    storage_manager_list = information_service.get_list_of('db_routers')

    if storage_manager_list.blank?
      slog('init', 'Error: db_routers list from IS is empty - there is no database to connect')

      # TODO: ugly hack to enable :environment in Rakefile for mongo tasks
      # raise 'db_routers list from IS is empty'
    else
      slog('init', "Fetched db_routers list: #{storage_manager_list}")
      db_router_url = storage_manager_list.sample
      slog('mongo_active_record', "Connecting to '#{db_router_url}'")
      begin
        Scalarm::Database::MongoActiveRecord.connection_init(db_router_url, config['db_name'],
                                                             username: config['auth_username'],
                                                             password: config['auth_password']
        )
      rescue Mongo::ConnectionFailure
        slog('mongo_active_record', 'Cannot connect to remote mongodb')
      end
    end
  end

  if Scalarm::Database::MongoActiveRecord.connected?
    MongoStore::Session.database = Scalarm::Database::MongoActiveRecord.get_database(config['db_name'])
  end

end