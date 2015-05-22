##
# Scalarm extensions for GridProxy
#
# Based on original grid-proxy: https://gitlab.dev.cyfronet.pl/commons/grid-proxy
#
# Copyright (c) 2013 Marek Kasztelnik
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
#                                  distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require_relative 'grid_proxy/proxy'
require_relative 'grid_proxy/exceptions'

require_relative 'logger'
require_relative 'configuration'

module Scalarm::ServiceCore::GridProxy
  class Proxy
    def verify_for_plgrid!
      crl = Scalarm::ServiceCore::Configuration.proxy_crl
      ca = Scalarm::ServiceCore::Configuration.proxy_ca
      Scalarm::ServiceCore::Logger.warn 'Proxy CRL not loaded' if crl.nil?
      raise 'Proxy CA not loaded' if ca.nil?
      verify!(ca, crl)
    end

    def valid_for_plgrid?
      begin
        verify_for_plgrid!
        true
      rescue GridProxy::ProxyValidationError => e
        false
      end
    end

    def dn
      proxycert.issuer.to_s
    end
  end
end
