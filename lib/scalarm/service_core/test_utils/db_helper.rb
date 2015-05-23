module Scalarm::ServiceCore::TestUtils
  module DbHelper
    DATABASE_NAME = 'scalarm_db_test'

    require 'scalarm/database/core/mongo_active_record'

    def setup(database_name=DATABASE_NAME)
      Scalarm::Database::MongoActiveRecord.set_encryption_key('db_key')

      unless Scalarm::Database::MongoActiveRecord.connected?
        begin
          connection_init = Scalarm::Database::MongoActiveRecord.connection_init('localhost', database_name)
        rescue Mongo::ConnectionFailure => e
          skip "Connection to database failed: #{e.to_s}"
        end
        skip 'Connection to database failed' unless connection_init
        #raise StandardError.new('Connection to database failed') unless connection_init
        puts "Connecting to database #{database_name}"
      end
    end

    # Drop all collections after each test case.
    def teardown(database_name=DATABASE_NAME)
      db = Scalarm::Database::MongoActiveRecord.get_database(database_name)
      if db.nil?
        puts 'Disconnection from database failed'
      else
        db.collections.each do |collection|
          collection.remove unless collection.name.start_with? 'system.'
        end
      end
    end
  end
end