module ScalarmAuthentication

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
    end

    if @current_user.nil? and @sm_user.nil?
      authentication_failed
    else
      if session.include?(:last_request)
        last_request_call = session[:last_request]

        if Time.now.to_i - last_request_call > Rails.configuration.session_threshold
          authentication_failed
          flash[:error] = t('session.expired')
        else
          session[:last_request] = Time.now.to_i
          flash[:notice] = t('login_success') unless @session_auth
        end
      else
        # this is our first request in the session
        session[:last_request] = Time.now.to_i
        flash[:notice] = t('login_success') unless @session_auth
      end

      @user_session = UserSession.find_by_session_id(session[:user])
      @user_session = UserSession.new(session_id: session[:user]) if @user_session.nil?
      @user_session.last_update = Time.now
      @user_session.save
    end
  end

  def authenticate_with_session
    Rails.logger.debug("[authentication] using session: #{session[:user]}")

    @user_session = UserSession.find_by_session_id(session[:user])

    if (not @user_session.nil?) and @user_session.valid?
      Rails.logger.debug("[authentication] scalarm user session exists and its valid")
      @current_user = ScalarmUser.find_by_id(session[:user])
      @session_auth = true unless @current_user.blank?
    else
      Rails.logger.debug("[authentication] scalarm user session doesnt exist and its invalid")
    end
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
      session[:user] = ScalarmUser.authenticate_with_certificate(cert_dn).id
      @current_user = ScalarmUser.find_by_id(session[:user])
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
      temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(login)

      unless temp_pass.nil?
        Rails.logger.debug("[authentication] SM using uuid: '#{login}'")

        @sm_user = temp_pass if ((not temp_pass.nil?) and (temp_pass.password == password))
      else
        Rails.logger.debug("[authentication] using login: '#{login}'")

        @current_user = ScalarmUser.authenticate_with_password(login, password)
      end

    end
  end

end
