source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.1.1'

# DB related gems - no active record, just MongoDB
gem 'mongo', '~> 1.12'
gem 'bson'
gem 'bson_ext'
gem 'mongo_session_store-rails4',
    git: 'git://github.com/kliput/mongo_session_store.git',
    branch: 'issue-31-mongo_store-deserialization'


gem 'rubyzip', '~> 0.9.9'

# Default web server
gem 'thin'

# third-party monitoring
gem 'newrelic_rpm'

gem 'sys-filesystem'

gem 'mocha', group: :test

## for local development - set path to scalarm-database
# gem 'scalarm-database', path: '/home/jliput/Scalarm/scalarm-database'
gem 'scalarm-database', '>= 0.3.3', git: 'git://github.com/Scalarm/scalarm-database.git'

## for local development - set path to scalarm-core
# gem 'scalarm-service_core', path: '/home/jliput/Scalarm/scalarm-service_core'
gem 'scalarm-service_core', '~> 0.9.1', git: 'git://github.com/Scalarm/scalarm-service_core.git'
