require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class PigeonSchedulerTest < Test::Unit::TestCase
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
  
  def test_defaults
    scheduler = Pigeon::Scheduler.new
    
    assert_equal true, scheduler.default_queue.empty?
  end
  
  def test_queued
    queue = Pigeon::Queue.new
    
    scheduler = Pigeon::Scheduler.new(queue)

    count = 1000
    
    count.times do |n|
      queue << TaggedTask.new(engine, n)
    end
    
    assert_eventually(5) do
      queue.empty?
    end
    
    assert_equal 0, scheduler.processors.select(&:task?).length
    assert_equal 0, queue.length
  end
end