require 'minitest/autorun'
require 'mocha/mini_test'

require 'scalarm/service_core/logger'

class LoggerTest < MiniTest::Test

  def setup
    Scalarm::ServiceCore::Logger.clear_logger
  end

  def test_delegation
    logger = mock 'logger' do
      expects(:info).with('a').once
      expects(:debug).with('b').once
      expects(:warn).with('c').once
      expects(:error).with('d').once
    end

    Scalarm::ServiceCore::Logger.set_logger(logger)

    Scalarm::ServiceCore::Logger.info 'a'
    Scalarm::ServiceCore::Logger.debug 'b'
    Scalarm::ServiceCore::Logger.warn 'c'
    Scalarm::ServiceCore::Logger.error 'd'
  end

  def test_empty
    Scalarm::ServiceCore::Logger.info 'a'
  end

  def test_clear_logger
    logger = mock 'logger' do
      expects(:info).never
    end

    Scalarm::ServiceCore::Logger.set_logger(logger)
    Scalarm::ServiceCore::Logger.clear_logger

    Scalarm::ServiceCore::Logger.info 'a'
  end

end