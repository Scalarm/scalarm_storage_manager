Scalarm Storage Manager
=======================

It constitutes a persistence layer for the Scalarm platform. It provides two services: a clustered MongoDB and
a Log Bank for saving binary output from simulations within data farming experiments.

To run the services you need to fulfill the following requirements:

* Ruby version

We are currently working with Rubinius 2.2.1 installed via RVM.

* System dependencies

Any dependency required by native gems.

* Configuration

You need one configuration file ('scalarm.yml') in the config folder.
In this file you put the following information in the YAML format:

```
# where is the Information Service
information_service_url: localhost:11300
information_service_user: secret_login
information_service_pass: secret_password

# where Log Bank should store content
mongo_host: 'localhost'
mongo_port: 27017
db_name: 'scalarm_db'
binaries_collection_name: 'simulation_files'

# MongoDB settings

# host is optional - the service will take local ip address if host is not provided
#host: localhost

# MongoDB instance settings
db_instance_port: 30000
db_instance_dbpath: ./../../scalarm_db_data
db_instance_logpath: ./../../log/scalarm_db.log

# MongoDB configsrv settings
db_config_port: 28000
db_config_dbpath: ./../../scalarm_db_config_data
db_config_logpath: ./../../log/scalarm_db_config.log

# MongoDB router settings
db_router_host: localhost
db_router_port: 27017
db_router_logpath: ./../../log/scalarm_db_router.log
```

In addition, you need to download a MongoDB package for your system and unpack it in the root folder of Storage Manager.
The folder should be named 'mongodb' - this name is hardcoded in Rakefile.

* Log Bank is started/stopped with the following commnads:

```
$ rake log_bank:start
$ rake log_bank:stop
```

* MongoDB sharded instance is started/stopped with the following commnads:

```
$ rake db_instance:start
$ rake db_instance:stop
```

* MongoDB config service is started/stopped with the following commnads:

```
$ rake db_config_service:start
$ rake db_config_service:stop
```

* MongoDB router is started/stopped with the following commnads:

```
$ rake db_router:start
$ rake db_router:stop
```