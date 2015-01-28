require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

module TestModule
  def self.included(engine)
    engine.after_start do
      notify_was_started
    end
  end
end

class TestEngine < Pigeon::Engine
  include TestModule

  def notify_was_started
    pipe = @options[:pipe]
    
    pipe.puts("STARTED")
    pipe.flush
    pipe.close
  end
end

class ShutdownEngine < Pigeon::Engine
  after_start do
    self.terminate
  end
end

class CallbackTestEngine < Pigeon::Engine
  after_initialize do
    track(:after_initialize)
  end
  
  before_start do
    track(:before_start)
  end
  
  after_start do
    track(:after_start)
  end
  
  before_stop do
    track(:before_stop)
  end
  
  after_stop do
    track(:after_stop)

    @options[:pipe].close
  end
  
  def track(callback)
    @options[:pipe].puts(callback.to_s)
    @options[:pipe].flush
  end
end

class ShutdownCallbackTestEngine < Pigeon::Engine
  attr_accessor :callbacks
  
  after_start do
    @callbacks = [ ]
  end
  
  before_shutdown do |callback|
    @callbacks << callback
  end

  before_shutdown do |callback|
    @callbacks << callback
  end
end

class TestPigeonEngine < Minitest::Test
  def test_default_options
    assert TestEngine.engine_logger
    assert TestEngine.engine_logger.is_a?(Logger)
  end
  
  def test_example_subclass
    engine_pid = nil
    
    read_fd, write_fd = IO.pipe
    
    TestEngine.start(pipe: write_fd) do |pid|
      assert pid
      engine_pid = pid
    end
    
    write_fd.close
    
    Timeout::timeout(5) do
      assert_equal "STARTED\n", read_fd.readline
    end
    
    TestEngine.status do |pid|
      assert_equal engine_pid, pid
    end
    
    TestEngine.stop do |pid|
      assert_equal engine_pid, pid
    end

    TestEngine.status do |pid|
      assert_equal nil, pid
    end
  end

  def test_example_subclass_without_blocks
    engine_pid = nil
    
    read_fd, write_fd = IO.pipe
    
    engine_pid = TestEngine.start(pipe: write_fd)
    
    write_fd.close
    
    assert engine_pid
    
    Timeout::timeout(5) do
      assert_equal "STARTED\n", read_fd.readline
    end
    
    running_pid = TestEngine.status
    
    assert_equal engine_pid, running_pid
    
    assert_equal engine_pid, TestEngine.stop

    assert_equal nil, TestEngine.status
  end
  
  def test_callbacks
    engine_pid = nil
    
    read_fd, write_fd = IO.pipe
    
    CallbackTestEngine.start(pipe: write_fd) do |pid|
      assert pid
      engine_pid = pid
    end
    
    write_fd.close
    
    reported_status = false
    
    CallbackTestEngine.status do |pid|
      assert_equal engine_pid, pid
      reported_status = true
    end
    
    assert reported_status
    
    CallbackTestEngine.stop do |pid|
      assert_equal engine_pid, pid
    end

    CallbackTestEngine.status do |pid|
      assert_equal nil, pid
    end
    
    expected_callbacks = [
      :after_initialize,
      :before_start,
      :after_start,
      :before_stop,
      :after_stop
    ].freeze
    
    assert_equal expected_callbacks, read_fd.read.split(/\n/).collect(&:to_sym)
  end
  
  def test_shutdown_engine
    engine_pid = nil
    
    ShutdownEngine.start do |pid|
      engine_pid = pid
    end
    
    assert engine_pid
    
    assert_eventually(5) do
      !ShutdownEngine.status
    end
  end
  
  def test_shutdown_engine_with_blocking_callback
    e = nil
    
    Thread.new do
      Thread.abort_on_exception = true
      
      ShutdownCallbackTestEngine.launch do |_e|
        e = _e
      end
    end
      
    assert_eventually(5) do
      e
    end
    
    assert e, "Engine variable was not bound"
    assert_equal [ ], e.callbacks
    
    assert_eventually(5) do
      e.state == :running
    end

    e.shutdown!
    
    assert e.callbacks
    assert !e.callbacks.empty?
    assert_equal :running, e.state
    
    assert_equal 2, e.callbacks.length
    
    e.callbacks[0].call

    assert_equal :running, e.state

    e.callbacks[1].call

    assert_equal :terminated, e.state
  end
end
