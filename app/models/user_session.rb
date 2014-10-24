
class UserSession < MongoActiveRecord

  def self.collection_name
    'user_sessions'
  end

  def valid?
    if Time.now.to_i - self.last_update.to_i > Rails.configuration.session_threshold
      false
    else
      true
    end
  end

  def self.ids_auto_convert
    false
  end

  def self.create_and_update_session(user_id)
    session_id = BSON::ObjectId(user_id)

    session = UserSession.find_by_session_id(session_id)
    session = UserSession.new(session_id: session_id) if session.nil?
    session.last_update = Time.now
    session.save

    session
  end


end
