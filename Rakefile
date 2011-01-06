require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "pigeon"
    gem.summary = %Q{Simple daemonized EventMachine engine framework with plug-in support}
    gem.description = %Q{Pigeon is a simple way to get started building an EventMachine engine that's intended to run as a background job.}
    gem.email = "github@tadman.ca"
    gem.homepage = "http://github.com/twg/pigeon"
    gem.authors = %w[ tadman ]
    gem.add_development_dependency 'eventmachine'
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "pigeon #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
