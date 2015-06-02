require 'minitest/autorun'
require 'active_support/testing/declarative'
require 'mocha/mini_test'
require 'mocha/parameter_matchers'


require 'scalarm/service_core/test_utils/db_helper'

require 'scalarm/service_core/token_utils'
require 'scalarm/service_core/scalarm_authentication'
require 'scalarm/service_core/scalarm_user'
require 'scalarm/service_core/user_session'


class TokenUtilsTest < MiniTest::Test
  extend ActiveSupport::Testing::Declarative
  include Scalarm::ServiceCore::TestUtils::DbHelper

  def setup
    super

    @login = 'test_login'
    @user = Scalarm::ServiceCore::ScalarmUser.new(login: @login)
    @user.save
  end

  def teardown
    super
  end

  def test_token_generation_and_destroy
    require 'restclient'

    user_session = Scalarm::ServiceCore::UserSession.new(
        session_id: @user.id,
        uuid: SecureRandom.uuid,
        last_update: Time.now
    )

    url = 'url'
    payload = 'payload'
    m_token = 'token'

    assert (user_session.tokens == [] or user_session.tokens == nil),
           'User session tokens should be nil or empty array after session creation'

    Scalarm::ServiceCore::UserSession.stubs(:_gen_random_token).returns(m_token)

    Scalarm::ServiceCore::UserSession.stubs(:find_by_token).with(m_token).
        returns(:user_session)

    user_session.expects(:destroy_token!).with(m_token).once

    RestClient.expects(:post).with(
        url,
        payload,
        Mocha::ParameterMatchers::HasEntries.new(
            Scalarm::ServiceCore::ScalarmAuthentication::TOKEN_HEADER => m_token
        )
    )

    Scalarm::ServiceCore::TokenUtils.post(url, user_session, payload)
  end

end