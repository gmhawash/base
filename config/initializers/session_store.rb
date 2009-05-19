# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_ba_session',
  :secret      => '67ad904f155db9b2536fac342dd587888c17a1a08a7536fa72b2cbac5a4b28e94957076f41a97623f9966cb92ad9aaff091156b01b90a80cc3a7905ee66af140'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
