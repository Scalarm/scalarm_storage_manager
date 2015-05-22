require 'minitest/autorun'
require 'mocha/mini_test'

require 'scalarm/service_core/grid_proxy'

class ProxyValidationTest < MiniTest::Test

  def setup
  end

  def test_proxy_valid
    proxy_path = File.dirname(__FILE__) + '/proxy/proxy_valid.pem'

    unless File.exists?(proxy_path)
     skip "Proxy file for tests: #{proxy_path} does not exists. Consider putting a valid proxy here."
    end

    proxy_s = File.read(proxy_path)

    proxy = Scalarm::ServiceCore::GridProxy::Proxy.new(proxy_s)

    proxy.verify_for_plgrid!
    refute_nil proxy.valid_for_plgrid?
  end

  def test_proxy_invalid
    proxy_path = File.dirname(__FILE__) + '/proxy/proxy_invalid.pem'

    unless File.exists?(proxy_path)
      skip "Proxy file for tests: #{proxy_path} does not exists. Consider putting a valid proxy here."
    end

    proxy_s = File.read(proxy_path)

    proxy = Scalarm::ServiceCore::GridProxy::Proxy.new(proxy_s)

    assert_raises Scalarm::ServiceCore::GridProxy::ProxyValidationError do
      proxy.verify_for_plgrid!
    end
  end


end