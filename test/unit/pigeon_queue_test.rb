require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class PigeonQueueTest < Minitest::Test
  class TaggedTask < Pigeon::Task
    attr_accessor :tag
    
    def initialize(tag, options = nil)
      super(options)
      @tag = tag
    end
    
    def inspect
      "<#{@tag}>"
    end
  end

  def test_empty_state
    queue = Pigeon::Queue.new
    
    assert_equal 0, queue.length
    assert_equal true, queue.empty?
    
    assert_equal nil, queue.pop
    
    assert_equal [ ], queue.processors
  end
  
  def test_cycling
    engine do
      queue = Pigeon::Queue.new
    
      task = Pigeon::Task.new
    
      assert_equal task, queue << task
      
      assert_eventually do
        queue.peek == task
      end
    
      assert queue.peek
      assert_equal 1, queue.length
      assert !queue.empty?
    
      found_task = queue.pop
    
      assert_equal task, found_task
    
      assert_equal 0, queue.length
      assert queue.empty?
    end
  end
    
  def test_filtering
    engine do
      queue = Pigeon::Queue.new

      tasks = (0..9).to_a.collect do |n|
        queue << TaggedTask.new(n)
      end
      
      assert_eventually do
        queue.length == 10
      end
    
      assert_equal (0..9).to_a, tasks.to_a.collect(&:tag)
    
      assert_equal tasks[0], queue.peek

      selected_task = queue.peek do |task|
        task.tag > 0
      end

      assert_equal tasks[1], selected_task
    
      queue.filter(:over_7) do |task|
        task.tag > 7
      end

      assert_equal tasks[8], queue.peek(:over_7)
      assert_equal 2, queue.length(:over_7)
    
      pulled_task = queue.pop(:over_7)
    
      assert_equal 9, queue.length

      assert_equal tasks[9], queue.peek(:over_7)
      assert_equal 1, queue.length(:over_7)
    
      queue.pop(:over_7)

      assert_equal nil, queue.peek(:over_7)
      assert_equal 0, queue.length(:over_7)
      assert_equal true, queue.empty?(:over_7)
    
      new_task = queue << TaggedTask.new(10)
    
      assert_eventually do
        queue.include?(new_task)
      end
    
      assert_equal new_task, queue.peek(:over_7)
      assert_equal 1, queue.length(:over_7)
      assert_equal false, queue.empty?(:over_7)
    
      queue.claim(new_task)
    
      assert_equal nil, queue.peek(:over_7)
      assert_equal 0, queue.length(:over_7)
      assert_equal true, queue.empty?(:over_7)
    end
  end

  def test_observe
    engine do
      queue = Pigeon::Queue.new
    
      tasks = (0..9).to_a.collect do |n|
        queue << TaggedTask.new(n)
      end
    
      queue.filter(:odd) do |task|
        task.tag % 2 == 1
      end
      
      assert_eventually(2) do
        queue.length == 10
      end
    
      assert_equal tasks[1], queue.peek(:odd)
      assert_equal 5, queue.length(:odd)
    
      assert_equal [ tasks[1], tasks[3], tasks[5], tasks[7], tasks[9] ], queue.pull(:odd)
    
      assert_equal 5, queue.length
      assert_equal 0, queue.length(:odd)
    
      added_odd = nil
    
      queue.observe(:odd) do |task|
        added_odd = task
      end
    
      new_task = queue << TaggedTask.new(10)
      
      assert_eventually(2) do
        queue.include?(new_task)
      end
    
      assert_equal nil, added_odd

      odd_1 = queue << TaggedTask.new(11)
      
      assert_eventually(2) do
        queue.include?(odd_1)
      end
    
      assert_equal odd_1, added_odd

      claimed_task = nil
      has_run = false
    
      queue.observe(:odd) do |task|
        claimed_task = queue.claim(task)
        has_run = true
      end
    
      # Observer callbacks are not triggered on existing data, only on new
      # insertions.
      assert_equal false, has_run
      assert_equal nil, claimed_task
      assert_equal 7, queue.length
      assert_equal 1, queue.length(:odd)

      new_task = queue << TaggedTask.new(12)
      
      assert_eventually(2) do
        queue.include?(new_task)
      end
    
      assert_equal nil, claimed_task
      assert_equal 8, queue.length
      assert_equal 1, queue.length(:odd)

      odd_2 = queue << TaggedTask.new(13)
      
      assert_eventually(2) do
        claimed_task == odd_2
      end
    
      # Adding a task that matches the filter triggers the callback.
      assert_equal odd_2, claimed_task
      assert_equal true, has_run
    
      # Clear out all of the odd entries.
      queue.pull(:odd)
    
      claimed_task = nil
      has_run = false

      new_task = queue << TaggedTask.new(14)
      
      assert_eventually(2) do
        queue.include?(new_task)
      end

      assert_equal nil, claimed_task
      assert_equal false, has_run

      odd_2 = queue << TaggedTask.new(15)

      assert_eventually(2) do
        odd_2 == claimed_task
      end
    
      assert_equal odd_2, claimed_task
      assert_equal true, has_run

      assert_equal 8, queue.length
      assert_equal 0, queue.length(:odd)
    end
  end
  
  def test_can_add_during_observe
    engine do
      queue = Pigeon::Queue.new
    
      queue.observe do |task|
        if (task.tag < 10)
          queue.claim(task)

          queue << TaggedTask.new(task.tag + 1)
        end
      end
    
      new_task = queue << TaggedTask.new(0)
      
      assert_eventually(2) do
        queue.peek
      end

      assert queue.peek
      assert_equal 10, queue.peek.tag
      assert_equal 1, queue.length
      assert queue.peek
    end
  end
end
