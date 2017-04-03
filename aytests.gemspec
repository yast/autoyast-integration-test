Gem::Specification.new do |spec|
  # gem name and description
  spec.version = File.read(File.expand_path("../VERSION", __FILE__)).chomp
  spec.name    = "aytests"
  spec.summary = "Framework to run AutoYaST integration tests"
  spec.license = "GPL-3.0"

  # author
  spec.author   = "YaST team"
  spec.email    = "yast-devel@suse.com"
  spec.homepage = "http://github.org/yast/autoyast-integration-test"

  spec.description = <<-end
Framework to run AutoYaST integration tests. This gem does not contain any
integration test itself. A standard set of tests can be found in
http://github.com/yast/aytests-tests.
end

  spec.files        = Dir["bin/*", "lib/**/*.rb", "share/**/*", "spec/**/*",
                          "doc/*", "config/*", "Rakefile", "README.md", "VERSION"]

  spec.require_path = "lib"
  spec.bindir       = "bin"
  spec.executables  = ["aytests"]

  # dependencies
  spec.add_runtime_dependency("rspec", "~> 3.1", '>= 3.1.0')
  spec.add_runtime_dependency("net-ssh-simple", "~> 1.6", '>= 1.6.11')
  spec.add_runtime_dependency("ruby-libvirt", "~> 0.5", ">= 0.5.2")
  spec.add_runtime_dependency("cheetah", "~> 0.4", ">= 0.4.0")
  spec.add_runtime_dependency("thor", "~> 0.19", ">= 0.19.1")
  spec.add_runtime_dependency("mini_magick", "~> 4.0")
  spec.add_development_dependency("packaging_rake_tasks", "~> 1.0")
end
