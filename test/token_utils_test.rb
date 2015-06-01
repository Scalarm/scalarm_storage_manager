require 'minitest/autorun'
require 'active_support/testing/declarative'
require 'mocha/mini_test'

require 'scalarm/service_core/test_utils/db_helper'

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

  def test_token
    user_session = UserSession.new(
        session_id: @user.id,
        uuid: SecureRandom.uuid,
        last_update: Time.now
    )

    url = 'url'
    payload = 'payload'

    TokenUtils.stubs(:post).with(url, payload) do
      payload
      user_session.tokens.count == 1 and user_session
    end

    assert (user_sesion.tokens == [] or user_session.tokens == nil),
           'User session tokens should be nil or empty array after session creation'

    TokenUtils.post(url, user_session, payload)



    TokenUtils.get(url, user_session, params)
  end

end