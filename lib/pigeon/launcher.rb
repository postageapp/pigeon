require 'optparse'

class Pigeon::Launcher
  # == Class Methods ========================================================
  
  def self.launch(engine = Pigeon::Engine, *arguments)
    arguments = %w[ start ] if (arguments.empty?)
    
    new(engine).handle_args(*arguments)
  end
    
  # == Instance Methods =====================================================
    
  def initialize(with_engine = Pigeon::Engine)
    @engine = with_engine
    
    yield(self) if (block_given?)
  end
  
  def handle_args(*args)
    op = OptionParser.new
    
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
        @engine.engine_logger = Pigeon::Logger.new(STDOUT)

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
    log "#{@engine.name} now running. [%d]" % pid
    log "Use ^C to terminate."
  end
  
  def start(pid)
    log "#{@engine.name} now running. [%d]" % pid
  end
  
  def stop(pid)
    if (pid)
      log "#{@engine.name} shut down. [%d]" % pid
    else
      log "#{@engine.name} was not running."
    end
  end
  
  def status(pid)
    if (pid)
      log "#{@engine.name} running. [%d]" % pid
    else
      log "#{@engine.name} is not running."
    end
  end
  
  def restart(pid, old_pid)
    if (old_pid)
      log "#{@engine.name} terminated. [%d]" % old_pid
    end

    log "#{@engine.name} now running. [%d]" % pid
  end
  
  def shutdown(pid)
    log "Shutting down."
  end

  def usage
    log "Usage: #{File.basename($0)} [start|stop|restart|status|run]"
  end
  
  def log(message)
    puts message
  end
end
