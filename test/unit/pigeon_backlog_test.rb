require_relative '../helper'

class PigeonBacklogTest < Minitest::Test
  def test_empty_queue
    queue = Pigeon::Queue.new
    
    assert queue.empty?
    assert_equal 0, queue.length
    
    assert_nil queue.pop
  end
  
  def test_queue_cycling
    engine do
      queue = Pigeon::Queue.new
    
      task = Pigeon::Task.new
    
      queue << task
      
      assert_eventually(1) do
        !queue.empty?
      end
    
      assert_equal 1, queue.length
      assert !queue.empty?
    
      found_task = queue.pop
    
      assert_equal task, found_task
    
      assert_equal 0, queue.length
      assert queue.empty?
    end
  end
end
