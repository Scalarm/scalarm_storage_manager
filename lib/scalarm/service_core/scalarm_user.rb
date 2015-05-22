# Attributes
# _id => auto generated user id
# dn => distinguished user name from certificate
# login => last CN attribute value from dn

require 'scalarm/database/model/scalarm_user'

module Scalarm::ServiceCore
  class ScalarmUser < Scalarm::Database::Model::ScalarmUser

    def self.authenticate_with_password(login, password)
      user = ScalarmUser.find_by_login(login.to_s)

      if user.nil? || user.password_salt.nil? || user.password_hash.nil?  || Digest::SHA256.hexdigest(password + user.password_salt) != user.password_hash
        # TODO: raise some bad login or pass exception, then rescue it in controller in service
        raise "Bad login or password"
        #raise I18n.t('user_controller.login.bad_login_or_pass')
      end

      user
    end

    def self.authenticate_with_certificate(dn)
      # backward-compatibile: there are some dn's formatted by PL-Grid OpenID in database - try to convert
      user = (ScalarmUser.find_by_dn(dn.to_s) or
          ScalarmUser.find_by_dn(PlGridOpenID.browser_dn_to_plgoid_dn(dn)))

      if user.nil?
        raise "Authentication failed: user with DN = #{dn} not found"
      end

      user
    end

    ##
    # If proxy is valid (or validation is skipped), return ScalarmUser
    # with login matching with username from proxy.
    #
    # Arguments:
    # [proxy] GP::Proxy or String containing proxy certificate
    # [verify] If true, check if proxy is valid (default)
    def self.authenticate_with_proxy(proxy, verify=true)
      proxy = if proxy.is_a?(Scalarm::ServiceCore::GridProxy::Proxy)
                proxy
              else
                Scalarm::ServiceCore::GridProxy::Proxy.new(proxy)
              end

      ScalarmUser.where(login: proxy.username).first if !verify or proxy.valid_for_plgrid?
    end

    def banned_infrastructure?(infrastructure_name)
      if credentials_failed and credentials_failed.include?(infrastructure_name) and
          credentials_failed[infrastructure_name].count >= 2 and (compute_ban_end(credentials_failed[infrastructure_name].last) > Time.now)
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
      @anonymous_user ||= ScalarmUser.find_by_login(Utils::load_config['anonymous_login'].to_s)
    end

    def destroy_unused_credentials
      InfrastructureFacadeFactory.get_all_infrastructures.each do |infrastructure_facade|
        infrastructure_facade.destroy_unused_credentials(:x509_proxy, self)
      end
    end

    private

    def compute_ban_end(start_time)
      start_time + 5.minutes
    end

  end
end
