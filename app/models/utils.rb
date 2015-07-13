module Utils
  def self.load_database_config
    YAML.load_file("#{Rails.root}/config/scalarm.yml")
  end
end