require 'minitest/autorun'
require 'active_support/testing/declarative'
require 'mocha/mini_test'

require 'scalarm/service_core/logger'

require 'scalarm/service_core/test_utils/db_helper'

require 'scalarm/service_core/scalarm_user'

class ScalarmUserTest < MiniTest::Test
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

  def test_authenticate_with_password_success
    password = 'x'
    @user.password = password
    @user.save

    from_db = Scalarm::ServiceCore::ScalarmUser.authenticate_with_password(@login, password)

    refute_nil from_db

    user_hash = Hash[@user.to_h.collect {|k, v| [k.to_sym, v]}]
    db_hash = Hash[@user.to_h.collect {|k, v| [k.to_sym, v]}]

    assert_equal user_hash, db_hash
  end

  def test_authenticate_with_password_fail
    password = 'x'
    wrong_password = 'z'
    @user.password = password
    @user.save

    assert_raises Scalarm::ServiceCore::BadLoginOrPasswordError do
      Scalarm::ServiceCore::ScalarmUser.authenticate_with_password(@login, wrong_password)
    end
  end

  def test_authenticate_with_certificate_success
    dn = 'x'
    @user.dn = dn
    @user.save

    from_db = Scalarm::ServiceCore::ScalarmUser.authenticate_with_certificate(dn)

    refute_nil from_db

    user_hash = Hash[@user.to_h.collect {|k, v| [k.to_sym, v]}]
    db_hash = Hash[@user.to_h.collect {|k, v| [k.to_sym, v]}]

    assert_equal user_hash, db_hash
  end

  def test_authenticate_with_certificate_fail
    dn = 'x'
    wrong_dn = 'z'
    @user.dn = dn
    @user.save

    assert_raises Scalarm::ServiceCore::AuthenticationError do
      Scalarm::ServiceCore::ScalarmUser.authenticate_with_certificate(wrong_dn)
    end
  end

  test 'infrastructure should be banned after auth failure limit' do
    inf_name = 'one'
    failure_count = Scalarm::ServiceCore::ScalarmUser::MAX_CREDENTIALS_FAILURE_TRIES

    @user.credentials_failed = {'one' => []}

    failure_count.times { @user.credentials_failed[inf_name] << Time.now }

    assert @user.banned_infrastructure?(inf_name)
  end

  test 'infrastructure ban should be unlocked after some time' do
    require 'active_support/core_ext/numeric/time'

    inf_name = 'one'
    failure_count = Scalarm::ServiceCore::ScalarmUser::MAX_CREDENTIALS_FAILURE_TRIES
    ban_delay = (Scalarm::ServiceCore::ScalarmUser::BAN_TIME + 1.minute)

    @user.credentials_failed = {'one' => []}

    failure_count.times { @user.credentials_failed[inf_name] << (Time.now - ban_delay) }

    refute @user.banned_infrastructure?(inf_name)
  end

  test 'anonymous user should be nil without setting' do
    assert_nil Scalarm::ServiceCore::ScalarmUser.get_anonymous_user
  end

end