AYTESTS_COMPAT_WORK_DIR = File.join(File.dirname(__FILE__), "..", "..", "..", "workspace")

def run_aytests(cmd)
  $stderr.puts "rake interface is deprecated. Please, use aytests script "\
               "directly. The following command will be run:\n\n#{cmd}\n"
  libdir = File.join(Dir.pwd, "lib")
  system({"RUBYLIB" => libdir}, "./bin/aytests #{cmd}")
end

#
# Compatibility layer
#
desc "Running autoyast integration tests"
task :test, :name do |name, args|
  run_aytests("test #{args[:name]} --work-dir #{AYTESTS_COMPAT_WORK_DIR}")
end

desc "Building boot image <name>"
task :build_iso, :name do |name, args|
  run_aytests("build_iso #{args[:name]} --work-dir #{AYTESTS_COMPAT_WORK_DIR}")
end

# Cleaning tasks
# Temporary files
task :clean do
  run_aytests("clean --work-dir #{AYTESTS_COMPAT_WORK_DIR}")
end

# Final products
task :clobber do
  FileUtils.rm_r(AYTESTS_COMPAT_WORK_DIR)
end
