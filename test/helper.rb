require 'rubygems'
require 'bundler/setup'

require 'minitest'

module Minitest
  # The default Minitest behavior to intercept at_exit and rewrite the exit
  # status code based on test results is okay for the parent process, but
  # causes friction when using fork within tests. Here it's disabled unless
  # the process terminating is the parent.
  class << self
    undef_method(:autorun)
  end

  def self.autorun
    return if (defined?(@at_exit_hook_installed))

    @at_exit_hook_installed = Process.pid

    at_exit do
      next if $! and not ($!.kind_of? SystemExit and $!.success?)

      exit_code = Minitest.run(ARGV)

      @@after_run.reverse_each do |block|
        block.call

        if (Process.pid != @at_exit_hook_installed)
          break
        end
      end

      exit(exit_code)
    end
  end
end

require 'minitest/reporters'
require 'minitest/autorun'
require 'timeout'

Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)

$LOAD_PATH.unshift(File.expand_path(File.join(*%w[ .. lib ]), File.dirname(__FILE__)))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'pigeon'
require 'eventmachine'

class Minitest::Test
  def assert_timeout(time, message = nil, &block)
    Timeout::timeout(time, &block)

  rescue Timeout::Error
    flunk(message || 'assert_timeout timed out')
  end
  
  def assert_eventually(time = nil, message = nil)
    start_time = Time.now.to_f

    while (!yield)
      select(nil, nil, nil, 0.1)
      
      if (time and (Time.now.to_f - start_time > time))
        flunk(message || 'assert_eventually timed out')
      end
    end
  end

  def engine
    @engine = nil
    exception = nil
    test_thread = nil
    
    engine_thread =
      Thread.new do
        Thread.abort_on_exception = true

        Pigeon::Engine.clear_engines!

        # Create a thread for the engine to run on
        begin
          Pigeon::Engine.launch do |launched|
            @engine = launched
          end

        rescue Object => e
          # $stderr.puts('[%s] %s' % [ e.class, e ])
          # $stderr.puts(e.backtrace.join("\n"))

          exception = e

          Thread.current.kill
        end
      end

    test_thread =
      Thread.new do
        # Execute the test code in a separate thread to avoid blocking
        # the EventMachine loop.
        begin
          while (!@engine or Pigeon::Engine.default_engine != @engine)
            # Wait impatiently.
            if (exception)
              Thread.current.kill
            end
          end

          yield(@engine)
        rescue Object => e
          exception = e
        ensure
          begin
            if (EventMachine.reactor_running?)
              EventMachine.stop_event_loop
            end
          rescue Object
            STDERR.puts("[#{exception.class}] #{exception}")
            # Shutting down may trigger an exception from time to time
            # if the engine itself has failed.
          end
        end
      end

    test_thread.join

    begin
      Timeout.timeout(1) do
        engine_thread.join
      end
    rescue Timeout::Error
      engine_thread.kill
    end
    
    if (exception)
      raise exception
    end
  ensure
    if (engine_thread)
      engine_thread.kill
    end
  end
end
