require 'rest-client'
require_relative 'scalarm_authentication'

module Scalarm::ServiceCore

  class TokenUtils

    ##
    # Execute GET request with token authentication
    # @param [String] url
    # @param [Scalarm::ServiceCore::UserSession] user_session
    # @param [Hash] parameters
    # @param [Hash] headers
    # @return [RestClient::Response]
    def self.get(url, scalarm_user, parameters, headers={})
      scalarm_user.generate_token do |token|
        RestClient::Request.execute(
            method: :get,
            url: url,
            headers: headers.merge(
                params: parameters,
                ScalarmAuthentication::TOKEN_HEADER => token
            ),
            verify_ssl: false
        )
      end
    end

    ##
    # Execute POST request with token authentication
    # @param [String] url
    # @param [Scalarm::ServiceCore::UserSession] user_session
    # @param [Hash] parameters
    # @param [Hash] headers
    # @return [RestClient::Response]
    def self.post(url, scalarm_user, payload, headers={})
      scalarm_user.generate_token do |token|
        RestClient::Request.execute(
            method: :post,
            url: url,
            payload: payload,
            headers: headers.merge(
                ScalarmAuthentication::TOKEN_HEADER => token
            ),
            verify_ssl: false
        )
      end
    end

    ##
    # An old helper method, not used now
    def self._add_token_to_url(url, user_session=nil)
      user_session ? "#{url}?token=#{user_session.generate_token}" : url
    end

  end

end