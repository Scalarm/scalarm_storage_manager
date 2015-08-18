# Be sure to restart your server when you modify this file.

ScalarmStorageManager::Application.config.session_store :mongo_store, key: '_scalarm_session'
#Rails.application.config.action_dispatch.cookies_serializer = :hybrid