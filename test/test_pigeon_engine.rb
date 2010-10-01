require File.expand_path(File.join(*%w[ helper ]), File.dirname(__FILE__))

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

class TestPigeonEngine < Test::Unit::TestCase
  def test_create_subclass
    engine_pid = nil
    
    read_fd, write_fd = IO.pipe
    
    TestEngine.start(:pipe => write_fd) do |pid|
      assert pid
      engine_pid = pid
    end
    
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
end
