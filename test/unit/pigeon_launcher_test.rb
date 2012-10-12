require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class Pigeon::Launcher
  def log(*args)
    # Disabled for testing.
  end
end

class PigeonLauncherTest < Test::Unit::TestCase
  def test_default_launcher
    pid = Pigeon::Launcher.launch
    
    assert pid, "PID should be returned from launcher call"
    assert Pigeon::Engine.running?
    
    Pigeon::Engine.stop
    
    assert !Pigeon::Engine.running?
  end

  def test_triggers
    triggered = Hash.new do |h, k|
      h[k] = 0
    end
    
    Pigeon::Launcher.new(Pigeon::Engine).handle_args('start') do
      start do
        triggered[:start] += 1
      end
    end

    Pigeon::Launcher.new(Pigeon::Engine).handle_args('restart') do
      restart do
        triggered[:restart] += 1
      end
    end

    Pigeon::Launcher.new(Pigeon::Engine).handle_args('status') do
      status do
        triggered[:status] += 1
      end
    end

    Pigeon::Launcher.new(Pigeon::Engine).handle_args('stop') do
      stop do
        triggered[:stop] += 1
      end
    end
    
    # FIX: Test `run`
    
    if (false)
      assert_equal 1, triggered[:start]
      assert_equal 1, triggered[:restart]
      assert_equal 1, triggered[:status]
      assert_equal 1, triggered[:stop]
    end
  end
end
