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
    op = OptionParser.new do |parser|
      parser.on('-v', '--version') do
        pigeon_version = 'Pigeon %s' % Pigeon.version

        version =
          if (@engine.respond_to?(:version))
            '%s (%s)' % [ @engine.version, pigeon_version ]
          else
            pigeon_version
          end

        puts version
        exit(0)
      end
    end
    
    command = op.parse(*args.flatten).first

    begin
      case (command)
      when 'start'
        @engine.start do |pid|
          yield(pid) if (block_given?)
          self.start(pid)
        end
      when 'stop'
        @engine.stop do |pid|
          yield(pid) if (block_given?)
          self.stop(pid)
        end
      when 'restart'
        @engine.restart do |pid, old_pid|
          yield(pid, old_pid) if (block_given?)
          self.restart(pid, old_pid)
        end
      when 'status'
        @engine.status do |pid|
          yield(pid) if (block_given?)
          self.status(pid)
        end
      when 'run'
        @engine.engine_logger = Pigeon::Logger.new(STDOUT)

        @engine.run do |pid|
          yield(pid) if (block_given?)
          self.run(pid)
        end
      else
        usage
      end

    rescue Interrupt
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
