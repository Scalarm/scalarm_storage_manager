require_relative 'db_helper'

module Scalarm::ServiceCore::TestUtils
  module AuthenticationTestCases
    require 'csv'
    require 'minitest/autorun'
    require 'test_helper'
    require 'mocha/test_unit'
    require 'scalarm/service_core/test_utils/db_helper'

    require 'scalarm/service_core/scalarm_user'
    require 'scalarm/service_core/user_session'
    require 'scalarm/service_core/grid_proxy'
    require 'scalarm/service_core/scalarm_authentication'

    include Scalarm::ServiceCore::TestUtils::DbHelper

    def setup
      super
    end

    def teardown
      super
      Scalarm::ServiceCore::Utils.unstub(:header_newlines_deserialize)
    end

    TESTS = [
        'authentication_proxy_success',
        'authentication_proxy_fail',
        'token',
        'basic_auth_success'
    ]

    def self.define_test(base_name)
      define_method "test_#{base_name}" do
        send("_test_#{base_name}")
      end
    end

    def self.define_all_tests
      TESTS.each do |test_name|
        define_test(test_name)
      end
    end

    def _test_authentication_proxy_success
      header_proxy = 'serialized proxy frome header'
      proxy = mock 'deserialized proxy'
      proxy_obj = mock 'proxy obj' do
        stubs(:class).returns(Scalarm::ServiceCore::GridProxy::Proxy)
        stubs(:username).returns('plguser')
        stubs(:dn).returns('dn')
        expects(:verify_for_plgrid!).at_least_once
      end

      u = Scalarm::ServiceCore::ScalarmUser.new(login: 'user')
      u.save
      u.stubs(:convert_to).returns(u)

      Scalarm::ServiceCore::Utils.stubs(:header_newlines_deserialize).with(header_proxy).returns(proxy)
      Scalarm::ServiceCore::GridProxy::Proxy.stubs(:new).with(proxy).returns(proxy_obj)
      Scalarm::ServiceCore::ScalarmUser.expects(:authenticate_with_proxy).
          at_least_once.with(proxy_obj, false).returns(u)
      Scalarm::ServiceCore::UserSession.stubs(:create_and_update_session)

      get '/', {}, { Scalarm::ServiceCore::ScalarmAuthentication::RAILS_PROXY_HEADER => header_proxy,
                     'HTTP_ACCEPT' => 'application/json' }

      assert_response :success, response.code
      body = JSON.parse(response.body)
      assert_equal 'ok', body['status']
      assert_equal u.id.to_s, body['user_id']

      # session creation on proxy authentication was disabled
      # assert_equal user_id.to_s, session[:user]
    end

    def _test_authentication_proxy_fail
      header_proxy = 'serialized proxy from header'
      proxy = mock 'deserialized proxy'
      proxy_obj = mock 'proxy obj' do
        stubs(:username).returns('plguser')
        stubs(:dn).returns('dn')
        expects(:verify_for_plgrid!).at_least_once.
            raises(Scalarm::ServiceCore::GridProxy::ProxyValidationError.new('test fail'))
      end
      user_id = BSON::ObjectId.new
      scalarm_user = mock 'scalarm user' do
        stubs(:id).returns(user_id)

        # for Experiment Manager conversion
        stubs(:convert_to).returns(scalarm_user)
      end

      Scalarm::ServiceCore::Utils.stubs(:header_newlines_deserialize).with(header_proxy).returns(proxy)
      Scalarm::ServiceCore::GridProxy::Proxy.stubs(:new).with(proxy).returns(proxy_obj)
      Scalarm::ServiceCore::ScalarmUser.stubs(:authenticate_with_proxy).with(proxy_obj, false).returns(scalarm_user)
      Scalarm::ServiceCore::ScalarmUser.stubs(:authenticate_with_proxy).with(proxy_obj, true).returns(nil)
      Scalarm::ServiceCore::UserSession.stubs(:create_and_update_session) do |_user_id, session_id|
        _user_id == user_id
      end

      get '/', {}, { Scalarm::ServiceCore::ScalarmAuthentication::RAILS_PROXY_HEADER => header_proxy,
                     'HTTP_ACCEPT' => 'application/json' }

      assert_response 401, response.code
      assert_equal 'error', JSON.parse(response.body)['status']
    end

    ##
    # Generate token manually, check if it appeared in DB, then make request
    # on the end, token should be destroyed
    def _test_token
      u = Scalarm::ServiceCore::ScalarmUser.new(login: 'user')
      token = u.generate_token
      u.save

      assert_equal token, u.reload.tokens[0]
      get '/', {token: token}, {'HTTP_ACCEPT' => 'application/json'}
      assert_response :success, response.body

      body = JSON.parse(response.body)
      assert_equal u.id.to_s, body['user_id'], body

      assert_empty u.reload.tokens
    end

    def _test_basic_auth_success
      login = 'user'
      password = 'pass'

      u = Scalarm::ServiceCore::ScalarmUser.new(login: login)
      u.password = password
      u.save

      get '/', {}, {
                 'HTTP_ACCEPT' => 'application/json',
                 'HTTP_AUTHORIZATION' =>
                     ActionController::HttpAuthentication::Basic.encode_credentials(login, password)
             }

      assert_response :success, response.body
      body = JSON.parse(response.body)
      assert_equal u.id.to_s, body['user_id'], body
    end
  end
end