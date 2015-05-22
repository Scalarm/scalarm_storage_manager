module Scalarm::ServiceCore
  class AuthenticationError < StandardError; end

  class BadLoginOrPasswordError < AuthenticationError
    def to_s
      'Bad login or password'
    end
  end
end