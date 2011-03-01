require 'optparse'

class Pigeon::Launcher
  # == Class Methods ========================================================
  
  def self.launch(engine, options)
  end
    
  # == Instance Methods =====================================================
    
  def initialize(with_engine = Pigeon::Engine)
    @engine = with_engine
    @options = { }
  end
  
  def handle_args(*args)
    op = OptionParser.new
    
    op.on("-s", "--supervise") do
      @options[:supervise] = true
    end
    
    command = op.parse(*args.flatten).first

    begin
      case (command)
      when 'start'
        @engine.start(&method(:start))
      when 'stop'
        @engine.stop(&method(:stop))
      when 'restart'
        @engine.restart(&method(:restart))
      when 'status'
        @engine.status(&method(:status))
      when 'run'
        @engine.logger = Pigeon::Logger.new(STDOUT)

        @engine.run(&method(:run))
      else
        usage
      end
    rescue Interrupt
      shutdown(pid)
      exit(0)
    end
  end
  
  def run(pid)
    puts "#{@engine.name} now running. [%d]" % pid
    puts "Use ^C to terminate."
  end
  
  def start(pid)
    puts "#{@engine.name} now running. [%d]" % pid
  end
  
  def stop(pid)
    if (pid)
      puts "#{@engine.name} shut down. [%d]" % pid
    else
      puts "#{@engine.name} was not running."
    end
  end
  
  def status(pid)
    if (pid)
      puts "#{@engine.name} running. [%d]" % pid
    else
      puts "#{@engine.name} is not running."
    end
  end
  
  def restart(pid, old_pid)
    if (old_pid)
      puts "#{@engine.name} terminated. [%d]" % old_pid
    end

    puts "#{@engine.name} now running. [%d]" % pid
  end
  
  def shutdown(pid)
    puts "Shutting down."
  end

  def usage
    puts "Usage: #{File.basename($0)} [start|stop|restart|status|run]"
  end
end
