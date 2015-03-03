![Scalarm Logo](http://scalarm.com/images/scalarmNiebieskiemale.png)

Scalarm Storage Manager
=======================

It constitutes a persistence layer for the Scalarm platform. It provides two services: a clustered MongoDB and
a Log Bank for saving binary output from simulations within data farming experiments.

To run the services you need to fulfill the following requirements:

Ruby version
------------
Currently we use and test Scalarm against MRI 2.1.2 but the Rubinius version of Ruby should be good as well.

```sh
curl -L https://get.rvm.io | bash
```

Agree on anything they ask :)

```sh
source $HOME/.rvm/scripts/rvm
rvm install 2.1.2
```

Also agree on anything. After the last command, rubinius version of ruby will be downloaded and installed from source.


System dependencies
-------------------

For SL 6.4 you need to add nginx repo and then install:

```
yum install git vim nginx wget man libxml2 sqlite sqlite-devel R curl sysstat
```

Some requirements will be installed by rvm also during ruby installation.

Any dependency required by native gems.

Installation
------------

You can download it directly from GitHub

```
git clone https://github.com/Scalarm/scalarm_storage_manager
```

A dependency which is not provided in MongoDB - for the Linux OS you can download it with:

```
wget http://www.mongodb.org/dr//fastdl.mongodb.org/linux/mongodb-linux-x86_64-2.6.3.tgz/download
mv download download.tar.gz
tar xzvf download.tar.gz
mv mongodb-linux-x86_64-2.6.0 mongodb
rm download.tar.gz``
```

After downloading the code you just need to install gem requirements:

```
cd scalarm_storage_manager
bundle install
```

if any dependency is missing you will be noticed :)

Configuration
-------------

There are three files with configuration: config/secrets.yml, config/scalarm.yml and config/thin.yml.

The "secrets.yml" file is a standard configuration file added in Rails 4 to have a single place for all secrets in
an application. We used this approach in our Scalarm platform. Experiment Manager stores access data to Information Service in this file:

```
default: &DEFAULT
  information_service_url: "localhost:11300"
  secret_key_base: "<you need to change this - with $rake secret>"
  information_service_user: "<set to custom name describing your Scalarm instance>"
  information_service_pass: "<generate strong password instead of this>"
  load_balancer:
      # if you installed and want to use scalarm custom load balancer set to false
      disable_registration: true
      # if you use load balancer you need to specify multicast address (to receive load balancer address)
      #multicast_address: "224.1.2.3:8000"
      # if you use load balancer on http you need to specify this
      #development: true
      # if you want to run and register service in load balancer on other port than default
      #port: "20000"

development:
  <<: *DEFAULT

test:
  <<: *DEFAULT

production:
  secret_key_base: <%= ENV["SECRET_KEY_BASE"] %>
  information_service_url: "<%= ENV["INFORMATION_SERVICE_URL"] %>"
  information_service_user: "<%= ENV["INFORMATION_SERVICE_LOGIN"] %>"
  information_service_pass: "<%= ENV["INFORMATION_SERVICE_PASSWORD"] %>"
  # if you installed and want to use scalarm custom load balancer set to false
  load_balancer:  
    disable_registration: true
```

In the second file, 'scalarm.yml', you put the following information in the YAML format:

```
# where Log Bank should store content
mongo_host: 'localhost'
mongo_port: 27017
db_name: 'scalarm_db'
binaries_collection_name: 'simulation_files'

monitoring:
  db_name: 'scalarm_monitoring'
  metrics: 'cpu:memory:storage'
  interval: 60

# MongoDB settings

# host is optional - the service will take local ip address if host is not provided
host: localhost

# MongoDB instance settings
db_instance_port: 30000
db_instance_dbpath: ./../../scalarm_db_data
db_instance_logpath: ./../../log/scalarm_db.log

# MongoDB configsrv settings
db_config_port: 28000
db_config_dbpath: ./../../scalarm_db_config_data
db_config_logpath: ./../../log/scalarm_db_config.log

# MongoDB router settings
# db_router_host is optional - if not provided then the 'host' parameter will be taken
db_router_host: localhost
db_router_port: 27017
db_router_logpath: ./../../log/scalarm_db_router.log
```

The last file, 'thin.yml', is a standard configuration file for the Thin server (the Log Bank service is exposed through
this server):
```
pid: tmp/pids/thin.pid
log: log/thin.log
environment: production
socket: /tmp/scalarm_storage_manager.sock
tag: ScalarmStorageManager
```

Storage Manager has a few services to start:

```
export RAILS_ENV=production
```

1 - MongoDB config service
```
rake db_config_service:start
```

2 - MongoDB instance
```
rake db_instance:start
```

3 - MongoDB router
```
rake db_router:start
```

3 - Storage Manager Log Bank
```
rake log_bank:start
```

With the configuration as above Storage Manager Log Bank will be listening on linux socket. To make it available for other services we will use a HTTP server - nginx - which will also handle SSL.
To configure NGINX you basically need to add some information to NGINX configuration, e.g. in the /etc/nginx/conf.d/default.conf file.

```
# ================ SCALARM STORAGE MANAGERS
upstream scalarm_storage_manager {
  server unix:/tmp/scalarm_storage_manager.sock;
}

server {
  listen 20000 ssl;
  client_max_body_size 0;

  ssl_certificate /etc/nginx/server.crt;
  ssl_certificate_key /etc/nginx/server.key;

  ssl_verify_client optional;
  ssl_client_certificate /etc/grid-security/certificates/PolishGrid.pem;
  ssl_verify_depth 5;
  ssl_session_timeout 30m;

  location / {
    proxy_pass http://scalarm_storage_manager;

    proxy_set_header SSL_CLIENT_S_DN $ssl_client_s_dn;
    proxy_set_header SSL_CLIENT_I_DN $ssl_client_i_dn;
    proxy_set_header SSL_CLIENT_VERIFY $ssl_client_verify;
    proxy_set_header SSL_CLIENT_CERT $ssl_client_cert;
    proxy_set_header X-Real-IP  $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-Proto https; # New header for SSL

    break;
  }
}
```

To check if Storage Manager Log Bank started successfully you can check the status method:

```
curl -k https://localhost:20000/status
Hello world from Scalarm LogBank, it's 2014-04-30 17:01:45 +0200 at the server!
```

One last thing to do is to register Storage Manager Log Bank in the Scalarm Information Service. With the presented configuration (and assuming we are working on a hypothetical IP address 172.16.67.77) we just need to:

```
curl -k -u scalarm:scalarm -F "address=172.16.67.77:20000" https://localhost:11300/storage_managers
```

When running in a production-like environment please replace the secret token in the config/initializers/secret_token.rb with the value generated by:

```
rake secret
```

License
----

MIT
