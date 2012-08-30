require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift(File.expand_path(*%w[ .. lib ]), File.dirname(__FILE__))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'timeout'

require 'rubygems'

begin
  gem 'eventmachine'
rescue => e
  raise "EventMachine gem is not installed or could not be loaded: [#{e.class}] #{e}"
end

require 'pigeon'

class Test::Unit::TestCase
  def assert_timeout(time, message = nil, &block)
    Timeout::timeout(time, &block)
  rescue Timeout::Error
    flunk(message || 'assert_timeout timed out')
  end
  
  def assert_eventually(time = nil, message = nil, &block)
    start_time = Time.now.to_i

    while (!block.call)
      select(nil, nil, nil, 0.1)
      
      if (time and (Time.now.to_i - start_time > time))
        flunk(message || 'assert_eventually timed out')
      end
    end
  end

  def engine
    exception = nil

    @engine_thread = Thread.new do
      Thread.abort_on_exception = true

      # Create a thread for the engine to run on
      begin
        Pigeon::Engine.launch do |new_engine|
          @engine = new_engine
          
          Thread.new do
            # Execute the test code in a separate thread to avoid blocking
            # the EventMachine loop.
            begin
              yield
            rescue Object => exception
            ensure
              begin
                @engine.terminate
              rescue Object
                # Shutting down may trigger an exception from time to time
                # if the engine itself has failed.
              end
            end
          end
        end
      rescue Object => exception
      end
    end
    
    @engine_thread.join
    
    if (exception)
      raise exception
    end
  end
end
