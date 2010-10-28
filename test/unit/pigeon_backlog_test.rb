require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class PigeonQueueTest < Test::Unit::TestCase
  def test_empty_queue
    queue = Pigeon::Queue.new
    
    assert queue.empty?
    assert_equal 0, queue.length
    
    assert_equal nil, queue.pop
  end
  
  def test_queue_cycling
    queue = Pigeon::Queue.new
    
    task = Pigeon::Task.new
    
    queue << task
    
    assert_equal 1, queue.length
    assert !queue.empty?
    
    found_task = queue.pop
  end
end
