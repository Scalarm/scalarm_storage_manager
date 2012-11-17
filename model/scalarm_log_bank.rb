class ScalarmLogBank

  def initialize(config)
    if config.nil?
      raise Exception.new("Bad argument - empty config")
    end

    @config = config
  end

  def execute(command)
    if not ["start", "stop", "status"].include?(command)
      raise Exception.new("Bad command - should be (start|stop|status)")
    end

    puts "ScalarmLogBank executes #{command}"
  end

end