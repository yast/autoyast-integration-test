def run_aytests(cmd)
  $stderr.puts "rake interface is deprecated. Please, use ay-tests script "\
               "directly. Anyway, the command will be run."
  puts cmd
  system cmd
end

#
# Compatibility layer
#
task :test, :name do |name, args|
  run_aytests("./bin/ay-tests test #{args[:name]}")
end

task :build_iso, :name do |name, args|
  run_aytests("./bin/ay-tests build_iso #{args[:name]}")
end

# Cleaning tasks
# Temporary files
task :clean do
  run_aytests("./bin/ay-tests clean")
end

# Final products
task :clobber do
  run_aytests("./bin/ay-tests clobber")
end
