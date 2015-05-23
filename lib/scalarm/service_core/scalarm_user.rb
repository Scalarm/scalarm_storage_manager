# Attributes
# _id => auto generated user id
# dn => distinguished user name from certificate
# login => last CN attribute value from dn

require 'active_support/core_ext/numeric/time'

require 'scalarm/database/model/scalarm_user'

require_relative 'exceptions'

module Scalarm::ServiceCore
  class ScalarmUser < Scalarm::Database::Model::ScalarmUser

    def self.authenticate_with_password(login, password)
      user = ScalarmUser.find_by_login(login.to_s)

      if user.nil? || user.password_salt.nil? || user.password_hash.nil?  || Digest::SHA256.hexdigest(password + user.password_salt) != user.password_hash
        raise BadLoginOrPasswordError.new
        # TODO: above error should cause display of below message in services
        #raise I18n.t('user_controller.login.bad_login_or_pass')
      end

      user
    end

    def self.authenticate_with_certificate(dn)
      # backward-compatibile: there are some dn's formatted by PL-Grid OpenID in database - try to convert
      # TODO this conversion will be removed some day
      user = (ScalarmUser.find_by_dn(dn.to_s) or
          ScalarmUser.find_by_dn(browser_dn_to_plgoid_dn(dn)))

      if user.nil?
        raise AuthenticationError.new "Authentication failed: user with DN = #{dn} not found"
      end

      user
    end

    ##
    # Utility: convert DN from PL-Grid OpenID to web browser format
    def self.plgoid_dn_to_browser_dn(dn)
      '/' + dn.split(',').reverse.join('/')
    end

    ##
    # Utility: convert DN web browser format to PL-Grid OpenID format
    def self.browser_dn_to_plgoid_dn(dn)
      dn.split('/').slice(1..-1).reverse.join(',')
    end

    ##
    # If proxy is valid (or validation is skipped), return ScalarmUser
    # with login matching with username from proxy.
    #
    # Arguments:
    # [proxy] GP::Proxy or String containing proxy certificate
    # [verify] If true, check if proxy is valid (default)
    def self.authenticate_with_proxy(proxy, verify=true)
      proxy = if proxy.class <= Scalarm::ServiceCore::GridProxy::Proxy
                proxy
              else
                Scalarm::ServiceCore::GridProxy::Proxy.new(proxy)
              end

      if !verify or proxy.valid_for_plgrid?
        ScalarmUser.where(proxy.username).first
      else
        nil
      end
    end

    MAX_CREDENTIALS_FAILURE_TRIES = 2
    BAN_TIME = 5.minutes

    def banned_infrastructure?(infrastructure_name)
      if credentials_failed and credentials_failed.include?(infrastructure_name) and
          credentials_failed[infrastructure_name].count >= MAX_CREDENTIALS_FAILURE_TRIES and
          (compute_ban_end(credentials_failed[infrastructure_name].last) > Time.now)
        true
      else
        false
      end
    end

    def ban_expire_time(infrastructure_name)
      if credentials_failed and credentials_failed[infrastructure_name] and credentials_failed[infrastructure_name].count > 0
        compute_ban_end(credentials_failed[infrastructure_name].last)
      else
        nil
      end
    end

    def self.get_anonymous_user
      @anonymous_user ||= ScalarmUser.find_by_login(Configuration.anonymous_login.to_s)
    end

    def destroy_unused_credentials
      InfrastructureFacadeFactory.get_all_infrastructures.each do |infrastructure_facade|
        infrastructure_facade.destroy_unused_credentials(:x509_proxy, self)
      end
    end

    private

    def compute_ban_end(start_time)
      start_time + BAN_TIME
    end

  end
end
