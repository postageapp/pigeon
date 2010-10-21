require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class PigeonDispatcherTest < Test::Unit::TestCase
  def test_routine_dispatching
    dispatcher = Pigeon::Dispatcher.new
    
    assert_equal Pigeon::Dispatcher.thread_limit, dispatcher.thread_limit
    
    checks = { }
    
    count = 1000
    
    count.times do |n|
      dispatcher.perform do
        x = 0

        1000.times do
          dispatcher.perform do 
            x += 1
          end
        end
        
        checks[n] = x
      end
    end
    
    dispatcher.wait!

    assert_equal 0, dispatcher.backlog_size
    assert_equal 0, dispatcher.thread_count
    assert dispatcher.empty?
    assert_equal [ ], dispatcher.exceptions
    assert !dispatcher.exceptions?
    
    assert_equal (0..count - 1).to_a, checks.keys.sort
  end

  def test_dispatch_variants
    dispatcher = Pigeon::Dispatcher.new
    
    result = [ ]
    
    dispatcher.perform do
      result[0] = :a
    end
    
    dispatcher.perform(:b) do |b|
      result[1] = b
    end

    dispatcher.perform(:c, :d) do |c, d|
      result[2] = c
      result[3] = d
    end
    
    dispatcher.wait!
    
    assert_equal [ :a, :b, :c, :d ], result
  end
end
