desc "Set up the system to run tests"
task :setup do
  require_relative "../ay_tests/installer"
  config_file = Pathname.new(File.dirname(__FILE__)).join("..", "..", "config", "setup.yml")
  installer = AYTests::Installer.new(YAML.load_file(config_file), ENV["LOGNAME"])
  installer.run
end
