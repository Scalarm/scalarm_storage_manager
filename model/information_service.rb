require "net/http"

class InformationService

  def initialize(config)
    @config = config
  end

  def send_request(request, data = nil)
    puts "#{Time.now} --- sending #{request} request to the Information Service"

    http = Net::HTTP.new(@config["information_service_host"], @config["information_service_port"].to_i)

    req = if data.nil?
            Net::HTTP::Get.new("/" + request)
          else
            Net::HTTP::Post.new("/" + request)
          end
    #puts "#{@config["information_service_login"]}, #{@config["information_service_password"]}"
    req.basic_auth(@config["information_service_login"], @config["information_service_password"])
    req.set_form_data(data) if not data.nil?

    begin
      response = http.request(req)
      puts "#{Time.now} --- response from Information Service is #{response.body}"

      return response.body
    rescue Exception => e
      puts "Exception occured but nothin terrible :) - #{e.message}"
    end

    nil
  end

end