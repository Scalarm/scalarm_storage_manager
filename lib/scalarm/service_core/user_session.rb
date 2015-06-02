require 'securerandom'

require 'scalarm/database/model/user_session'

module Scalarm::ServiceCore
  class UserSession < Scalarm::Database::Model::UserSession

    def valid?
      if Time.now.to_i - self.last_update.to_i > Rails.configuration.session_threshold
        false
      else
        true
      end
    end

    def self.create_and_update_session(user_id, uuid)
      session_id = BSON::ObjectId(user_id.to_s)
      if uuid.nil?
        uuid = session[:session_uuid] = SecureRandom.uuid
      end

      session = (UserSession.where(session_id: session_id, uuid: uuid).first or
        UserSession.new(session_id: session_id, uuid: uuid))
      session.last_update = Time.now
      session.save

      session
    end

    def self.find_by_token
      UserSession.where(tokens: token).first
    end

    ##
    # Generate token and save record to database
    # If block given - yield token and destroy after block finish
    def generate_token
      token = self.class._gen_random_token
      self.tokens = [] unless self.tokens
      self.tokens << token
      self.save

      if block_given?
        begin
          yield token
        ensure
          self.destroy_token!(token)
        end
      else
        token
      end
    end

    def self._gen_random_token
      SecureRandom.uuid
    end

    ##
    # Destroy token and save record only if exists
    def destroy_token!(token)
      token = self.tokens.delete(token)
      self.save if token
      token
    end

  end
end
