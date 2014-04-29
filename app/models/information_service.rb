require 'openssl'
require 'net/https'
require 'json'

class InformationService

  def initialize(url, username, password)
    @service_url = url
    @username = username
    @password = password
  end

  def register_service(service, host, port)
    send_request("#{service}/register", {address: "#{host}:#{port}"})
  end

  def deregister_service(service, host, port)
    send_request("#{service}/deregister", {address: "#{host}:#{port}"})
  end

  def get_list_of(service)
    send_request("#{service}/list")
  end

  def send_request(request, data = nil)
    @host, @port = @service_url.split(':')
    puts "#{Time.now} --- sending #{request} request to the Information Service at '#{@host}:#{@port}'"

    req = if data.nil?
            Net::HTTP::Get.new('/' + request)
          else
            Net::HTTP::Post.new('/' + request)
          end


    req.basic_auth(@username, @password)
    req.set_form_data(data) unless data.nil?

    ssl_options = { use_ssl: true, ssl_version: :SSLv3, verify_mode: OpenSSL::SSL::VERIFY_NONE }

    begin
      response = Net::HTTP.start(@host, @port, ssl_options) { |http| http.request(req) }
      if response.code != '200'
        puts "#{Time.now} - [is] There was a problem since the response code is #{response.code}"
        return nil
      else
        puts "#{Time.now} - [is] response is #{response.body}"
      end

      return JSON.parse(response.body)
    rescue Exception => e
      puts "#{Time.now} - [is] Exception occurred but nothing terrible :) - #{e.message}"
    end

    nil
  end

end
