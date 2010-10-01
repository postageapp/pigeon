require File.expand_path(File.join(*%w[ helper ]), File.dirname(__FILE__))

class PigeonQueueTest < Test::Unit::TestCase
  def test_simple_queue
    queue = Pigeon::Queue.new
    
    checks = { }
    
    count = 1000
    
    count.times do |n|
      queue.perform do
        x = 0
        10_000.times { x += 1 }
        checks[n] = true
      end
    end
    
    while (!queue.empty?)
      sleep(1)
    end

    assert queue.empty?
    assert_equal [ ], queue.exceptions
    assert !queue.exceptions?
    
    assert_equal (0..count - 1).to_a, checks.keys.sort
  end
end
