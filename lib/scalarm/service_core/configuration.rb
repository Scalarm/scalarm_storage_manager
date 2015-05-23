module Scalarm::ServiceCore

  class Configuration
    require 'active_support/core_ext/class/attribute_accessors'

    DEFAULT_PROXY_CA_PATH = "#{File.dirname(__FILE__)}/../../proxy/plgrid_ca.pem"
    DEFAULT_PROXY_CRL_PATH = "#{File.dirname(__FILE__)}/../../proxy/plgrid_crl.pem"

    ##
    # Load Proxy's CA from custom location.
    # By default, bundled CA is used.
    def self.load_proxy_ca(path)
      @@proxy_ca = File.read(path)
    end

    ##
    # Load Proxy's CRL from custom location.
    # By default, bundled CRL is used.
    def self.load_proxy_crl(path)
      @@proxy_crl = File.read(path)
    end

    load_proxy_ca(DEFAULT_PROXY_CA_PATH)
    load_proxy_crl(DEFAULT_PROXY_CRL_PATH)

    cattr_reader :proxy_ca
    cattr_reader :proxy_crl

    cattr_accessor :anonymous_login
    cattr_accessor :anonymous_password

  end

end