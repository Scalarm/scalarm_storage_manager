module Scalarm::ServiceCore
  class Logger
    @@logger = nil

    def self.set_logger(logger)
      @@logger = logger
    end

    def self.clear_logger
      @@logger = nil
    end

    def self.method_missing(name, *arguments, &block)
      @@logger.send(name, *arguments, &block) unless @@logger.nil?
    end
  end
end
