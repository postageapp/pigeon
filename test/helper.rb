require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift(File.expand_path(*%w[ .. lib ]), File.dirname(__FILE__))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rubygems'

if (Gem.available?('eventmachine'))
  gem 'eventmachine'
else
  raise "EventMachine gem is not installed."
end

require 'pigeon'

class Test::Unit::TestCase
end
