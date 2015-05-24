require 'scalarm/service_core/scalarm_authentication'

class ApplicationController < ActionController::Base
  include Scalarm::ServiceCore::ScalarmAuthentication

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  before_filter :start_monitoring
  after_filter :stop_monitoring

  rescue_from Scalarm::ServiceCore::AuthenticationError,
              with: :authentication_failed

  @@probe = MonitoringProbe.new

  protected

  def authentication_failed
    Rails.logger.debug('[authentication] failed -> 401')

    reset_session
    @user_session.destroy unless @user_session.nil?

    render inline: 'Authentication failed', status: 401
  end

  def start_monitoring
    #@probe = MonitoringProbe.new
    @action_start_time = Time.now
  end

  def stop_monitoring
    processing_time = ((Time.now - @action_start_time)*1000).to_i.round
    #Rails.logger.info("[monitoring][#{controller_name}][#{action_name}]#{processing_time}")
    @@probe.send_measurement(controller_name, action_name, processing_time)
  end

end
