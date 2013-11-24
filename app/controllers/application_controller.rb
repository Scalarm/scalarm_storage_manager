class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  #protect_from_forgery with: :exception

  protected

  # should return true if OK or false if NOT OK
  def authenticate

    if request.env.include?('HTTP_SSL_CLIENT_S_DN') and
        request.env['HTTP_SSL_CLIENT_S_DN'] != '(null)' and
        request.env['HTTP_SSL_CLIENT_VERIFY'] == 'SUCCESS'

      puts "We can use DN(#{request.env['HTTP_SSL_CLIENT_S_DN']}) for authentication"
      scalarm_user = ScalarmUser.find_by_dn(request.env['HTTP_SSL_CLIENT_S_DN'])

      return true if scalarm_user.nil?
    end

    if request.env.include?('HTTP_AUTHORIZATION') and request.env['HTTP_AUTHORIZATION'].include?('Basic')
      authenticate_or_request_with_http_basic do |sm_uuid, password|
        Rails.logger.debug("Possible SM authentication: #{sm_uuid}")
        temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(sm_uuid)

        return true if (not temp_pass.nil?) and temp_pass.password == password
      end
    end

    false
  end

end
