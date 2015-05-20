require 'minitest/autorun'
require 'mocha/mini_test'

require 'scalarm/service_core/logger'

class LoggerTest < MiniTest::Test

  def setup
    Logger.clear_logger
  end

  def test_delegation
    logger = mock 'logger' do
      expects(:info).with('a').once
      expects(:debug).with('b').once
      expects(:warn).with('c').once
      expects(:error).with('d').once
    end

    Logger.set_logger(logger)

    Logger.info 'a'
    Logger.debug 'b'
    Logger.warn 'c'
    Logger.error 'd'
  end

  def test_empty
    Logger.info 'a'
  end

  def test_clear_logger
    logger = mock 'logger' do
      expects(:info).never
    end

    Logger.set_logger(logger)
    Logger.clear_logger

    Logger.info 'a'
  end

end