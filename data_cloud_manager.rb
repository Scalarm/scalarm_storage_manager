require "rubygems"
require 'rack'
require "data_mapper"
require 'socket'

require "./model/storage_manager"
require "./data_cloud"

port = 20000
cmd = "start"
if ARGV.size > 0
    cmd = ARGV[0]
else
    puts "usage: data_cloud_manager.rb (start|stop) <port>"
    exit(1)
end

if ARGV.size > 1
    port = ARGV[1].to_i
end

host = ""
UDPSocket.open{|s| s.connect('64.233.187.99', 1); host = s.addr.last}

puts "Cmd: #{cmd} --- Port: #{port}"
pid_file = "/tmp/data_cloud_pid_file_#{port}"

# ORM setting
log = File.new("sinatra.log", "a+")
$stdout.reopen(log)
$stderr.reopen(log)

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default,
    :adapter  => 'mysql',
    :user     => 'root',
    :password => 'bin63zN',
    :host     => '10.1.2.32',
    :database => 'eusas_production')
DataMapper.finalize

case cmd

when "start" then
    if File.exist?(pid_file)
        puts "server already running"
        exit(1)
    else
        pid = fork do
            app = Cyfronet::DataCloud
            handler = Rack::Handler::Thin
            handler.run(app, :Port => port) do |server|
                puts "Application url is: #{host}:#{port}"
                StorageManager.register(host, port)
            end
        end
        File.open(pid_file, "w") {|file| file.puts pid}
        Process.detach(pid)
    end

when "stop" then
    pid = nil
    if not File.exist?(pid_file)
        puts "server is not running ?"
        exit(1)
    else
        StorageManager.deregister(host, port)
        File.open(pid_file, "r") {|file| pid = file.gets.to_i}
        File.delete(pid_file)
        Process.kill("TERM", pid)
    end

end
