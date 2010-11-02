require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class PigeonProcessorTest < Test::Unit::TestCase
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

  def test_empty_processor
    queue = Pigeon::Queue.new
    
    processor = Pigeon::Processor.new(queue)
    
    assert_equal false, processor.task?
    
    assert_equal true, processor.accept?(Pigeon::Task.new(engine))
    
    assert processor.id
  end
  
  def test_simple_filter
    queue = Pigeon::Queue.new
    
    processor = Pigeon::Processor.new(queue) do |task|
      (task.tag % 2) == 1
    end
    
    assert_equal false, processor.task?
    
    queue << TaggedTask.new(engine, 0)
    
    assert_equal false, processor.task?
    assert_equal 1, queue.length

    queue << TaggedTask.new(engine, 1)
    
    assert_equal true, processor.task?
    assert_equal 1, queue.length
    
    assert_eventually(5) do
      !processor.task?
    end
    
    assert_equal 1, queue.length
  end

  def test_on_backlog
    queue = Pigeon::Queue.new
    
    100.times do |n|
      queue << TaggedTask.new(engine, n)
    end
    
    processor = Pigeon::Processor.new(queue)
    
    assert_eventually(5) do
      queue.empty?
    end
  end

  def test_multiple_processors
    queue = Pigeon::Queue.new
    count = 10000
    
    count.times do |n|
      queue << TaggedTask.new(engine, n)
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
