# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{pigeon}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["tadman"]
  s.date = %q{2010-10-19}
  s.default_executable = %q{launcher.example}
  s.description = %q{Pigeon is a simple way to get started building an EventMachine engine that's intended to run as a background job.}
  s.email = %q{github@tadman.ca}
  s.executables = ["launcher.example"]
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "bin/launcher.example",
     "lib/pigeon.rb",
     "lib/pigeon/engine.rb",
     "lib/pigeon/launcher.rb",
     "lib/pigeon/logger.rb",
     "lib/pigeon/option_accessor.rb",
     "lib/pigeon/pidfile.rb",
     "lib/pigeon/queue.rb",
     "lib/pigeon/support.rb",
     "pigeon.gemspec",
     "test/helper.rb",
     "test/test_pigeon.rb",
     "test/test_pigeon_engine.rb",
     "test/test_pigeon_launcher.rb",
     "test/test_pigeon_option_accessor.rb",
     "test/test_pigeon_queue.rb"
  ]
  s.homepage = %q{http://github.com/tadman/pigeon}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Simple daemonized EventMachine engine framework with plug-in support}
  s.test_files = [
    "test/helper.rb",
     "test/test_pigeon.rb",
     "test/test_pigeon_engine.rb",
     "test/test_pigeon_launcher.rb",
     "test/test_pigeon_option_accessor.rb",
     "test/test_pigeon_queue.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<eventmachine>, [">= 0"])
    else
      s.add_dependency(%q<eventmachine>, [">= 0"])
    end
  else
    s.add_dependency(%q<eventmachine>, [">= 0"])
  end
end

