## Configuration files should be placed in the 'etc' folder.

#### --- config.yml ---
    # Information service url and credentials
    information_service_host: localhost
    information_service_port: 11200
    information_service_login: username
    information_service_password: mypass

#### --- log_bank.yml ---
    # at which port the service should listen
    host: 10.1.2.17
    port: 20000
    # where log bank should store content
    mongo_host: 'localhost'
    mongo_port: 27017
    db_name: 'scalarm_binaries'
    binaries_collection_name: 'simulation_files'

#### --- scalarm_db.yml ---
    # MongoDB instance settings
    db_instance_port: 30000
    db_instance_dbpath: scalarm_db_data
    db_instance_logpath: ./../../log/scalarm_db.log

    # MongoDB configsrv settings
    db_config_port: 28000
    db_config_dbpath: ./../../log/scalarm_db_config_data
    db_config_logpath: ./../../log/scalarm_db_config.log

    # MongoDB router settings
    db_router_port: 27017
    db_router_logpath: ./../../log/scalarm_db_router.log



