# each authentication method must set:
# - session[:user] to user id as string,
# - @current_user or @sm_user to scalarm user or simulation manager temp pass respectively
# - @session_auth to true if this is session-based authentication
module ScalarmAuthentication
  require 'openid'

  # the main authentication function + session management
  def authenticate
    Rails.logger.debug("[authentication] starting")
    @current_user = nil; @sm_user = nil; @session_auth = false; @user_session = nil

    case true
      when (not session[:user].blank?)
        authenticate_with_session

      when password_provided?
        authenticate_with_password

      when certificate_provided?
        authenticate_with_certificate

      when token_provided?(params)
        authenticate_with_token(params[:token])
    end

    if @current_user.nil? and @sm_user.nil?
      authentication_failed
    else
      @user_session = UserSession.create_and_update_session(@current_user.id.to_s) if @sm_user.nil?
    end
  end

  def authenticate_with_token(token)
    @user_session = ScalarmAuthentication.find_session_by_token(token)
    if @user_session
      @user_session.tokens = @user_session.tokens.delete(token)
      validate_and_use_session
    else
      Rails.logger.warn("Invalid token provided for login: #{token}")
    end
  end

  def self.find_session_by_token(token)
    UserSession.where(tokens: token).first
  end

  def authenticate_with_session
    Rails.logger.debug("[authentication] using session: #{session[:user]}")
    session_id = BSON::ObjectId(session[:user].to_s)

    @user_session = UserSession.find_by_session_id(session_id)
    validate_and_use_session
  end

  def validate_and_use_session
    if (not @user_session.nil?) and @user_session.valid?
      Rails.logger.debug("[authentication] scalarm user session exists and its valid")
      @current_user = ScalarmUser.find_by_id(@user_session.session_id)
      @session_auth = true unless @current_user.blank?
    else
      flash[:error] = t('session.expired')
      Rails.logger.debug("[authentication] scalarm user session doesnt exist and its invalid")
    end
  end

  def token_provided?(params)
    !!params[:token]
  end

  def certificate_provided?
    request.env.include?('HTTP_SSL_CLIENT_S_DN') and
        request.env['HTTP_SSL_CLIENT_S_DN'] != '(null)' and
        request.env['HTTP_SSL_CLIENT_VERIFY'] == 'SUCCESS'
  end

  def authenticate_with_certificate
    cert_dn = request.env['HTTP_SSL_CLIENT_S_DN']
    Rails.logger.debug("[authentication] using DN: '#{cert_dn}'")

    begin
      session[:user] = ScalarmUser.authenticate_with_certificate(cert_dn).id.to_s
      @current_user = ScalarmUser.find_by_id(session[:user].to_s)
    rescue Exception => e
      @current_user = nil
      flash[:error] = e.to_s
    end
  end

  def password_provided?
    request.env.include?('HTTP_AUTHORIZATION') and request.env['HTTP_AUTHORIZATION'].include?('Basic')
  end

  def authenticate_with_password
    authenticate_or_request_with_http_basic do |login, password|
      temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(login.to_s)

      unless temp_pass.nil?
        Rails.logger.debug("[authentication] SM using uuid: '#{login}'")

        @sm_user = temp_pass if ((not temp_pass.nil?) and (temp_pass.password == password))
      else
        Rails.logger.debug("[authentication] using login: '#{login}'")

        @current_user = ScalarmUser.authenticate_with_password(login, password)
        session[:user] = @current_user.id.to_s unless @current_user.nil?
      end

    end
  end

end