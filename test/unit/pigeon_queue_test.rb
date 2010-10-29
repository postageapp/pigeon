require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class PigeonQueueTest < Test::Unit::TestCase
  class TaggedTask < Pigeon::Task
    attr_accessor :tag
    
    def initialize(engine, tag)
      super(engine)
      @tag = tag
    end
    
    def inspect
      "<#{@tag}>"
    end
  end
  
  def engine
    @engine ||= Pigeon::Engine.new
  end

  def test_empty_state
    queue = Pigeon::Queue.new
    
    assert_equal 0, queue.length
    assert_equal true, queue.empty?
    
    assert_equal nil, queue.pop
  end
  
  def test_cycling
    queue = Pigeon::Queue.new
    
    task = Pigeon::Task.new(engine)
    
    assert_equal task, queue << task
    
    assert queue.peek
    assert_equal 1, queue.length
    assert !queue.empty?
    
    found_task = queue.pop
    
    assert_equal task, found_task
    
    assert_equal 0, queue.length
    assert queue.empty?
  end
    
  def test_filtering
    queue = Pigeon::Queue.new

    tasks = (0..9).to_a.collect do |n|
      queue << TaggedTask.new(engine, n)
    end
    
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
    
    new_task = queue << TaggedTask.new(engine, 10)
    
    assert_equal new_task, queue.peek(:over_7)
    assert_equal 1, queue.length(:over_7)
    assert_equal false, queue.empty?(:over_7)
    
    queue.claim(new_task)
    
    assert_equal nil, queue.peek(:over_7)
    assert_equal 0, queue.length(:over_7)
    assert_equal true, queue.empty?(:over_7)
  end

  def test_observe
    queue = Pigeon::Queue.new
    
    tasks = (0..9).to_a.collect do |n|
      queue << TaggedTask.new(engine, n)
    end
    
    queue.filter(:odd) do |task|
      task.tag % 2 == 1
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
    
    queue << TaggedTask.new(engine, 10)
    
    assert_equal nil, added_odd

    odd_1 = queue << TaggedTask.new(engine, 11)
    
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

    queue << TaggedTask.new(engine, 12)
    
    assert_equal nil, claimed_task
    assert_equal 8, queue.length
    assert_equal 1, queue.length(:odd)

    odd_2 = queue << TaggedTask.new(engine, 13)
    
    # Adding a task that matches the filter triggers the callback.
    assert_equal odd_2, claimed_task
    assert_equal true, has_run
    
    # Clear out all of the odd entries.
    queue.pull(:odd)
    
    claimed_task = nil
    has_run = false

    queue << TaggedTask.new(engine, 14)

    assert_equal nil, claimed_task
    assert_equal false, has_run

    odd_2 = queue << TaggedTask.new(engine, 15)
    
    assert_equal odd_2, claimed_task
    assert_equal true, has_run

    assert_equal 8, queue.length
    assert_equal 0, queue.length(:odd)
  end
  
  def test_can_add_during_observe
    queue = Pigeon::Queue.new
    
    queue.observe do |task|
      if (task.tag < 10)
        queue.claim(task)

        queue << TaggedTask.new(engine, task.tag + 1)
      end
    end
    
    queue << TaggedTask.new(engine, 0)

    assert queue.peek
    assert_equal 10, queue.peek.tag
    assert_equal 1, queue.length
    assert queue.peek
  end
end
