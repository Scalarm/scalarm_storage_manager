require 'minitest/autorun'
require 'mocha/mini_test'
require 'active_support/testing/declarative'

require 'scalarm/service_core/test_utils/db_helper'

require 'scalarm/service_core/scalarm_authentication'

class ScalarmAuthenticationTest < MiniTest::Test
  extend ActiveSupport::Testing::Declarative
  include Scalarm::ServiceCore::TestUtils::DbHelper

  def setup
    super
  end

  def teardown
    super
  end

  def test_find_user_by_token
    u = Scalarm::ServiceCore::ScalarmUser.new(login: 'user')
    u.save

    generated_token = nil
    u.generate_token do |token|
      generated_token = token
      found_user = Scalarm::ServiceCore::ScalarmAuthentication.find_user_by_token(token)
      refute_nil found_user
      assert_equal found_user.id, u.id
    end

    ## Check if generated token disappeared
    found_user_2 = Scalarm::ServiceCore::ScalarmAuthentication.find_user_by_token(generated_token)
    assert_nil found_user_2
  end

  # TODO: write DummyController tests - skipped now because of many mocking issues

  # class DummyController
  #   include Scalarm::ServiceCore::ScalarmAuthentication
  #
  #   attr_accessor :sm_user
  #   attr_accessor :session
  #
  #   def initialize(username, password)
  #     @username = username
  #     @password = password
  #
  #     @session = {}
  #   end
  #
  #   def authenticate_or_request_with_http_basic(&block)
  #     yield @username, @password
  #   end
  # end
  #
  # test 'successful authentication with sm_uuid' do
  #   require 'scalarm/database/model/simulation_manager_temp_password'
  #
  #   sm_uuid = 'some_uuid'
  #   password = 'some_password'
  #   experiment_id = BSON::ObjectId.new
  #   tp = Scalarm::Database::Model::SimulationManagerTempPassword.new(
  #       sm_uuid: sm_uuid, password: password, experiment_id: experiment_id
  #   )
  #   tp.save
  #
  #   controller = DummyController.new(sm_uuid, password)
  #
  #   controller.authenticate_with_password
  #
  #   assert_equal tp.id, controller.sm_user.id
  # end
  #
  # test 'successful authentication with scalarm user' do
  #   require 'scalarm/service_core/scalarm_user'
  #
  #   login = 'some_login'
  #   password = 'some_password'
  #   user = Scalarm::ServiceCore::ScalarmUser.new(
  #       login: login
  #   )
  #   user.password = password
  #   user.save
  #
  #   controller = DummyController.new(login, password)
  #
  #   controller.authenticate_with_password
  #
  #   assert_equal user.id.to_s, controller.session[:user].to_s
  #   refute_nil controller.session[:uuid]
  # end

end