require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class PigeonSchedulerTest < Test::Unit::TestCase
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

  def setup
    @engine = Pigeon::Engine.new

    Pigeon::Engine.register_engine(@engine)
  end
  
  def teardown
    Pigeon::Engine.unregister_engine(@engine)
  end
  
  def test_defaults
    scheduler = Pigeon::Scheduler.new
    
    assert_equal true, scheduler.default_queue.empty?
    assert_equal 0, scheduler.queue_size
    assert_equal true, scheduler.empty?
  end
  
  def test_queued
    queue = Pigeon::Queue.new
    
    scheduler = Pigeon::Scheduler.new(queue)

    count = 1000
    
    count.times do |n|
      queue << TaggedTask.new(n)
    end
    
    assert_eventually(5) do
      queue.empty?
    end
    
    assert_equal 0, scheduler.processors.select(&:task?).length
    assert_equal 0, queue.length
  end

  def test_add
    queue = Pigeon::Queue.new
    scheduler = Pigeon::Scheduler.new(queue)
    
    assert scheduler.processors.length > 0

    count = 1000
    backlog = [ ]

    count.times do |n|
      scheduler.add(TaggedTask.new(n * 2 + 1))
      backlog << TaggedTask.new(n * 2)
    end
    
    scheduler.add(backlog)
    
    assert_eventually(5) do
      queue.empty?
    end
    
    assert_equal 0, scheduler.processors.select(&:task?).length
    assert_equal 0, queue.length
  end
end
