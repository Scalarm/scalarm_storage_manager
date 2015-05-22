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

require_relative 'exceptions'

module Scalarm::ServiceCore::GridProxy
  class Proxy
    CERT_START = '-----BEGIN CERTIFICATE-----'

    attr_reader :proxy_payload

    def initialize(proxy_payload, username_prefix = 'plg')
      @proxy_payload = proxy_payload
      @username_prefix = username_prefix
    end

    def proxycert
      @proxycert ||= cert_for_element(1)
    end

    def proxykey
      begin
        @proxykey ||= OpenSSL::PKey.read(proxy_element(1))
      rescue
        nil
      end
    end

    def usercert
      @usercert ||= cert_for_element(2)
    end

    def verify!(ca_cert_payload, crl_payload = nil)
      now = Time.now
      raise ProxyValidationError.new('Proxy is not valid yet') if now < proxycert.not_before
      raise ProxyValidationError.new('Proxy expired') if now > proxycert.not_after
      raise ProxyValidationError.new('Usercert not signed with trusted certificate') unless ca_cert_payload && usercert.verify(cert(ca_cert_payload).public_key)
      raise ProxyValidationError.new('Proxy not signed with user certificate') unless proxycert.verify(usercert.public_key)

      proxycert_issuer = proxycert.issuer.to_s
      proxycert_subject = proxycert.subject.to_s

      raise ProxyValidationError.new('Proxy and user cert mismatch') unless proxycert_issuer == usercert.subject.to_s
      raise ProxyValidationError.new("Proxy subject must begin with the issuer") unless proxycert_subject.to_s.index(proxycert_issuer) == 0
      raise ProxyValidationError.new("Couldn't find '/CN=' in DN, not a proxy") unless proxycert_subject.to_s[proxycert_issuer.size, proxycert_subject.to_s.size].to_s.include?('/CN=')

      raise ProxyValidationError.new("Private proxy key missing") unless proxykey
      raise ProxyValidationError.new("Private proxy key and cert mismatch") unless proxycert.check_private_key(proxykey)

      raise ProxyValidationError.new("User cert was revoked") if crl_payload != nil and revoked? crl_payload
    end

    def valid?(ca_cert_payload, crl_payload = nil)
      begin
        verify! ca_cert_payload, crl_payload
        true
      rescue ProxyValidationError => e
        false
      end
    end

    def revoked?(crl_payload)
      # crl should to be verified with ca cert
      # crl(crl_payload).verify()

      #check for usercert serial in list of all revoked certs
      revoked_cert = crl(crl_payload).revoked().detect do |revoked|
        revoked.serial == usercert.serial
      end

      return revoked_cert != nil ? true : false

    end

    def username
      username_entry = usercert.subject.to_a.detect do |el|
        el[0] == 'CN' && el[1].start_with?(@username_prefix)
      end

      username_entry ? username_entry[1] : nil
    end

    private

    def cert_for_element(element_nr)
      cert(proxy_element(element_nr))
    end

    def proxy_element(element_nr)
      "#{CERT_START}#{@proxy_payload.split(CERT_START)[element_nr]}"
    end

    def cert(payload)
      OpenSSL::X509::Certificate.new payload
    end

    def crl(payload)
      OpenSSL::X509::CRL.new payload
    end
  end
end
