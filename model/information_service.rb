require 'net/http'

module Scalarm

  class InformationService

    def initialize(host, port, username, password)
      @host = host
      @port = port
      @username = username
      @password = password
    end

    def register_log_bank(host, port)
      send_request('register_log_bank', { server: host, port: port })
    end

    def deregister_log_bank(host, port)
      send_request('deregister_log_bank', { server: host, port: port })
    end

    def send_request(request, data = nil)
      puts "#{Time.now} --- sending #{request} request to the Information Service at '#{@host}:#{@port}'"

      http = Net::HTTP.new(@host, @port)

      req = if data.nil?
              Net::HTTP::Get.new('/' + request)
            else
              Net::HTTP::Post.new('/' + request)
            end

      req.basic_auth(@username, @password)
      req.set_form_data(data) if not data.nil?

      begin
        response = http.request(req)
        puts "#{Time.now} --- response from Information Service is #{response.body}"

        return response.body
      rescue Exception => e
        puts "Exception occurred but nothing terrible :) - #{e.message}"
      end

      nil
    end

  end

end
