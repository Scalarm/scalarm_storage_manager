require 'rubygems'
require 'data_mapper'

class ExperimentInstanceDb
    include DataMapper::Resource

    property :id,           Serial
    property :ip,           String
    property :port,         String
    property :created_at,   DateTime, :default => Time.now
    property :updated_at,   DateTime, :default => Time.now

    def self.register(host, port)
        puts "Registering ExperimentInstanceDb - #{host}:#{port}"
        if ExperimentInstanceDb.all(:ip => host, :port => port).count == 0
            sm = ExperimentInstanceDb.create(:ip => host, :port => port)
            sm.save
        else
            puts "Given ExperimentInstanceDb is already registered"
        end
    end

    def self.deregister(host, port)
        puts "Deregistering ExperimentInstanceDb - #{host}:#{port}"
        if ExperimentInstanceDb.all(:ip => host, :port => port).count == 0
            puts "Given ExperimentInstanceDb is not registered"
        else
            sm = ExperimentInstanceDb.first(:ip => host, :port => port)
            sm.destroy
        end
    end
end
