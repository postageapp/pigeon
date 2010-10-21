require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift(File.expand_path(*%w[ .. lib ]), File.dirname(__FILE__))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'timeout'

require 'rubygems'

if (Gem.available?('eventmachine'))
  gem 'eventmachine'
else
  raise "EventMachine gem is not installed."
end

require 'pigeon'

class Test::Unit::TestCase
  def assert_timeout(time, message = nil, &block)
    Timeout::timeout(time, &block)
  rescue Timeout::Error
    fail!(message)
  end
  
  def assert_eventually(time = nil, message = nil, &block)
    start_time = Time.now.to_i

    while (!block.call)
      select(nil, nil, nil, 0.1)
      
      if (time and (Time.now.to_i - start_time > time))
        fail!(message)
      end
    end
  end
end
