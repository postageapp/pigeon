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

  def test_empty_queue
    queue = Pigeon::Queue.new
    
    assert_equal 0, queue.length
    assert_equal true, queue.empty?
    
    assert_equal nil, queue.pop
  end
  
  def test_queue_cycling
    queue = Pigeon::Queue.new
    
    task = Pigeon::Task.new(engine)
    
    assert_equal task, queue << task
    
    assert_equal 1, queue.length
    assert !queue.empty?
    
    found_task = queue.pop
    
    assert_equal task, found_task
    
    assert_equal 0, queue.length
    assert queue.empty?
  end
    
  def test_queue_filtering
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
  end
end
