require 'rest-client'
require_relative 'scalarm_authentication'

module Scalarm::ServiceCore

  class TokenUtils

    ##
    # Execute GET request with token authentication
    # @return [RestClient::Response]
    def self.get(url, scalarm_user, parameters={}, headers={})
      _request(:get, url, scalarm_user, parameters, headers)
    end

    ##
    # Execute POST request with token authentication
    # @return [RestClient::Response]
    def self.post(url, scalarm_user, payload, headers={})
      _request(:post, url, scalarm_user, payload, headers)
    end

    def self.put(url, scalarm_user, payload, headers={})
      _request(:put, url, scalarm_user, payload, headers)
    end

    def self.delete(url, scalarm_user, payload, headers={})
      _request(:delete, url, scalarm_user, payload, headers)
    end

    def self._request(method, url, scalarm_user, data, headers, verify_ssl=false)
      scalarm_user.generate_token do |token|
        req_hash = {
            method: method,
            url: url,
            headers: headers.merge(
                ScalarmAuthentication::TOKEN_HEADER => token
            ),
            verify_ssl: verify_ssl
        }

        if method == :get
          req_hash[:headers] = req_hash[:headers].merge(params: data)
        else
          req_hash[:payload] = data
        end

        RestClient::Request.execute(req_hash)
      end
    end

    ##
    # An old helper method, not used now
    def self._add_token_to_url(url, user_session=nil)
      user_session ? "#{url}?token=#{user_session.generate_token}" : url
    end

  end

end