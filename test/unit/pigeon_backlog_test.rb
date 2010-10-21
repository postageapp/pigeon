require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class PigeonBacklogTest < Test::Unit::TestCase
  def test_empty_backlog
    engine = Pigeon::Engine.new
    
    backlog = Pigeon::Backlog.new
    
    assert backlog.empty?
    assert backlog.running?
    assert !backlog.paused?
    assert !backlog.stopped?
    
    backlog.pause!
    
    assert !backlog.running?
    assert backlog.paused?
    assert !backlog.stopped?
    
    tasks = [ ]

    1000.times do
      task = Pigeon::Task.new(engine)
      
      tasks << task
      backlog << task
    end
    
    assert_equal 1000, tasks.count
    assert_equal 0, backlog.processors_count
    assert_equal 1000, backlog.queue_size
    
    backlog.run!
    
    sleep(1)

    assert_equal 1000, tasks.count
    assert_equal 0, backlog.processors_count
    assert_equal 1000, backlog.queue_size
  end
end
