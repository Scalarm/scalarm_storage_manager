require 'net/http'
require 'socket'
require 'ipaddr'
require 'openssl'

class LoadBalancerRegistration

  def self.get_load_balancer_address
    unless Rails.application.secrets.include? :load_balancer
      raise StandardError.new('load balancer configuration is missing in secrets.yml')
    end
    if Rails.application.secrets.load_balancer["multicast_address"].blank?
      raise StandardError.new("multicast_address is missing in secrets configuration")
    end
    multicast_addr, port  = Rails.application.secrets.load_balancer["multicast_address"].split(':')
    bind_addr = '0.0.0.0'
    message = 'error'
    counter = 4
    repeat = true
    while repeat
      repeat = false
      begin
        socket = UDPSocket.new
        membership = IPAddr.new(multicast_addr).hton + IPAddr.new(bind_addr).hton

        socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
        #socket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

        socket.bind(bind_addr, port)
        begin
          timeout(30) do
            message, _ = socket.recvfrom(20)
          end
          socket.close
        rescue Timeout::Error => e
          puts "Unable to receive load balancer address: #{e.message}"
        end
      rescue Errno::EADDRINUSE => e
        if counter > 0
          counter -= 1
          repeat = true
          puts "Unable to establish multicast connection, reattempt in 20s"
          sleep(20)
        else
          puts "Unable to establish multicast connection: #{e.message}"
        end
      rescue => e
        puts "Unable to establish multicast connection: #{e.message}"
      end
    end
    message.strip
  end

  def self.load_balancer_query(query_type)
    unless Rails.application.secrets.include? :load_balancer
      raise StandardError.new('load balancer configuration is missing in secrets.yml')
    end
    raise ArgumentError.new('Incorrect query to load balancer') unless ['register', 'deregister'].include?(query_type)
    message = self.get_load_balancer_address
    if message != 'error'
      port = (Rails.application.secrets.load_balancer["port"] or '20000')
      scheme = 'https'
      if Rails.application.secrets.load_balancer["development"]
        scheme = 'http'
      end
      load_balancer_address = "#{scheme}://#{message.strip}/#{query_type}"

      begin
        uri = URI(URI.encode(load_balancer_address))

        req = Net::HTTP::Post.new(uri)
        req.set_form_data(address: "localhost:#{port}", name: 'StorageManager')

        if scheme == 'https'
          ssl_options = {use_ssl: true, ssl_version: :SSLv3, verify_mode: OpenSSL::SSL::VERIFY_NONE}
        else
          ssl_options = {}
        end
        response = Net::HTTP.start(uri.host, uri.port, ssl_options) { |http| http.request(req) }

        puts "Load balancer message: #{response.body}"
      rescue StandardError, Timeout::Error => e
        puts "Registration to load balancer failed: #{e.message}"
        raise
      end
    end

  end

  def self.register
    self.load_balancer_query 'register'
  end

  def self.deregister
    self.load_balancer_query 'deregister'
  end

end