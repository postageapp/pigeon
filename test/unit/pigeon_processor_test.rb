require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class PigeonProcessorTest < Test::Unit::TestCase
  class TaggedTask < Pigeon::Task
    attr_accessor :tag
    attr_reader :last_task
    
    def initialize(tag, options = nil)
      super(options)
      @tag = tag
    end
    
    def inspect
      "<#{@tag}>"
    end
  end

  def setup
    @engine = Pigeon::Engine.new

    Pigeon::Engine.register_engine(@engine)
  end
  
  def teardown
    Pigeon::Engine.unregister_engine(@engine)
  end

  def test_empty_processor
    queue = Pigeon::Queue.new
    
    processor = Pigeon::Processor.new(queue)
    
    assert_equal false, processor.task?
    
    assert_equal true, processor.accept?(Pigeon::Task.new)
    
    assert processor.id
  end
  
  def test_simple_filter
    engine do
      queue = Pigeon::Queue.new
    
      processor = Pigeon::Processor.new(queue) do |task|
        (task.tag % 2) == 1
      end
    
      assert_equal false, processor.task?
    
      queue << TaggedTask.new(0)
    
      assert_eventually(1) do
        queue.length == 1
      end
    
      assert_equal false, processor.task?
      assert_equal 1, queue.length

      queue << TaggedTask.new(1)
    
      assert_eventually(1) do
        queue.length == 1
      end

      assert_equal 1, queue.length
    
      assert_eventually(5) do
        !processor.task?
      end
    end
  end

  def test_on_backlog
    queue = Pigeon::Queue.new
    
    100.times do |n|
      queue << TaggedTask.new(n)
    end
    
    processor = Pigeon::Processor.new(queue)
    
    assert_eventually(5) do
      queue.empty?
    end
  end
  
  def test_reassigning_queues
    engine do
      queue_a = Pigeon::Queue.new
      queue_b = Pigeon::Queue.new
    
      processor = Pigeon::Processor.new(queue_a)
    
      task_a = TaggedTask.new(0)
      assert !task_a.finished?
    
      queue_a << task_a
    
      assert_eventually(1) do
        task_a.finished?
      end
    
      processor.queue = queue_b
    
      task_b = TaggedTask.new(1)
      assert !task_b.finished?

      queue_b << task_b

      assert_eventually(1) do
        task_b.finished?
      end
    
      task_c = TaggedTask.new(2)

      queue_a << task_c

      sleep(1)
    
      assert_equal false, task_c.finished?
    end
  end
  
  def test_can_unassign_queue_from_processor
    engine do
      queue = Pigeon::Queue.new
      processor = Pigeon::Processor.new(queue)
    
      assert_equal queue, processor.queue
      assert_equal [ processor ], queue.processors
    
      processor.queue = nil
    
      assert_equal nil, processor.queue
      assert_equal [ ], queue.processors
    end
  end

  def test_multiple_processors
    engine do
      queue = Pigeon::Queue.new
      count = 10000
    
      count.times do |n|
        queue << TaggedTask.new(n)
      end
    
      assert_eventually(2) do
        queue.length == count
      end
    
      assert_equal count, queue.length
    
      processors = (0..9).to_a.collect do
        Pigeon::Processor.new(queue)
      end
    
      assert_eventually(10) do
        queue.empty?
      end
    
      assert_equal 0, processors.select(&:task?).length
      assert_equal 0, queue.length
    end
  end
end
