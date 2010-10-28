require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class ExampleTask < Pigeon::Task
  attr_accessor :triggers
  
  def state_initialized!
    transition_to_state(:state1)
  end

  def state_state1!
    transition_to_state(:state2)
  end

  def state_state2!
    transition_to_state(:state3)
    
    dispatch do
      sleep(3)
      transition_to_state(:state4)
    end
  end
  
  def state_state4!
    transition_to_state(:finished)
  end
  
  def after_initialized
    @triggers = [ :after_initialized ]
  end
  
  def before_state(state)
    @triggers << state
  end
  
  def after_finished
    @triggers << :after_finished
  end
end

class FailingTask < Pigeon::Task
  def state_initialized!
    invalid_method!
  end
end

class PigeonTaskTest < Test::Unit::TestCase
  def test_empty_task
    engine = Pigeon::Engine.new
    
    task = Pigeon::Task.new(engine)
    
    reported = false
    
    task.run! do
      reported = true
    end

    assert_eventually(5) do
      task.finished? and reported
    end
    
    assert_equal :finished, task.state

    assert_equal nil, task.exception
  end
  
  def test_example_task
    engine = Pigeon::Engine.new
    
    task = ExampleTask.new(engine)
    
    callbacks = [ ]
    
    task.run! do |state|
      callbacks << state
    end
    
    assert_eventually(5) do
      task.finished?
    end
    
    assert_equal nil, task.exception
    
    assert_equal :finished, task.state

    expected_triggers = [
      :after_initialized,
      :initialized,
      :state1,
      :state2,
      :state3,
      :state4,
      :finished,
      :after_finished
    ]
    
    assert_equal expected_triggers, task.triggers

    expected_callbacks = [
      :initialized,
      :state1,
      :state2,
      :state3,
      :state4,
      :finished
    ]

    assert_equal expected_callbacks, callbacks
  end

  def test_failing_task
    engine = Pigeon::Engine.new
    
    task = FailingTask.new(engine)
    
    reported = false
    
    task.run! do
      reported = true
    end
    
    assert_eventually(5) do
      task.failed? and reported
    end

    assert task.exception?
  end

  def test_block_notification
    engine = Pigeon::Engine.new
    
    task = Pigeon::Task.new(engine)

    states_triggered = [ ]

    task.run! do |state|
      states_triggered << state
    end
    
    assert_eventually(5) do
      task.finished?
    end
    
    assert_equal [ :initialized, :finished ], states_triggered
  end

  def test_priority_order
    engine = Pigeon::Engine.new
    
    tasks = (0..10).collect do
      task = Pigeon::Task.new(engine)

      # Trigger generation of default priority value
      task.priority

      task 
    end
    
    assert_equal tasks.collect(&:object_id), tasks.sort.collect(&:object_id)
  end
end
