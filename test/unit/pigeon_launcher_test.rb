require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class Pigeon::Launcher
  def log(*args)
    # Disabled for testing.
  end
end

class PigeonLauncherTest < Minitest::Test
  def test_default_launcher
    pid = Pigeon::Launcher.launch
    
    assert pid, "PID should be returned from launcher call"
    assert Pigeon::Engine.running?
    
    Pigeon::Engine.stop
    
    assert !Pigeon::Engine.running?
  end

  def test_triggers
    launcher = Pigeon::Launcher.new(Pigeon::Engine)

    triggered = Hash.new { |h,k| h[k] = [ ] }
    
    launcher.handle_args('start') do |pid|
      triggered[:start] << pid
    end

    launcher.handle_args('status') do |pid|
      triggered[:status] << pid
    end

    launcher.handle_args('restart') do |pid, old_pid|
      triggered[:restart] << pid
    end

    launcher.handle_args('status') do |pid|
      triggered[:status] << pid
    end

    launcher.handle_args('stop') do |pid|
      triggered[:stop] << pid
    end
    
    assert triggered[:start]
    assert_equal 1, triggered[:start].length


    assert triggered[:restart]
    assert_equal 1, triggered[:restart].length
    refute_equal triggered[:start], triggered[:restart]

    assert_equal triggered[:start] + triggered[:restart], triggered[:status]

    assert_equal triggered[:restart], triggered[:stop]
  end
end
