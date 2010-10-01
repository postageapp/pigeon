require 'eventmachine'
require 'socket'

class Pigeon::Engine
  # == Submodules ===========================================================

  class RuntimeError < Exception
  end
  
  # == Properties ===========================================================
  
  attr_reader :logger

  # == Constants ============================================================
  
  CHAINS = %w[
    after_initialize
    before_start
    after_start
    before_stop
    after_stop
  ].collect(&:to_sym).freeze
  
  PID_DIR = [
    File.expand_path(File.join(*%w[ .. .. .. .. shared run ]), File.dirname(__FILE__)),
    '/var/run',
    '/tmp'
  ].find { |path| File.exist?(path) and File.writable?(path) }

  LOG_DIR = [
    File.expand_path(File.join(*%w[ .. .. .. .. shared log ] ), File.dirname(__FILE__)),
    File.expand_path(File.join(*%w[ .. .. log ]), File.dirname(__FILE__)),
    '/tmp'
  ].find { |path| File.exist?(path) and File.writable?(path) }
  
  DEFAULT_OPTIONS = {
    :pid_file => File.expand_path('pigeon-engine.pid', PID_DIR)
  }.freeze

  # == Class Methods ========================================================
  
  def self.options_with_defaults(options = nil)
    options ? DEFAULT_OPTIONS.merge(options) : DEFAULT_OPTIONS
  end

  def self.launch_with_options(options = nil)
    EventMachine.run do
      new(options_with_defaults(options)).run
    end
  end
  
  def self.pid_dir
    PID_DIR
  end
  
  def self.pid_file(options = nil)
    Pigeon::Pidfile.new(options_with_defaults(options)[:pid_file])
  end

  def self.start(options = nil)
    pid = Pigeon::Support.daemonize do
      launch_with_options(options)
    end

    pid_file(options).create!(pid)
    yield(pid.to_i)
  end

  def self.run(options = nil)
    yield($$)
    launch_with_options((options || { }).merge(:foreground => true))
  end
  
  def self.stop(options = nil)
    pf = pid_file(options)
    pid = pf.contents
    
    if (pid)
      begin
        Process.kill('QUIT', pid)
      rescue Errno::ESRCH
        # No such process exception
        pid = nil
      end
      pf.remove!
    end

    yield(pid)
  end

  def self.restart(options = nil)
    self.stop(options)
    self.start(options)
  end
  
  def self.status(options = nil)
    yield(pid_file(options).contents)
  end

  def self.sql_logger
    f = File.open(File.expand_path("query.log", LOG_DIR), 'w+')
    f.sync = true
    
    Pigeon::Logger.new(f)
  end
  
  def self.log_dir
    LOG_DIR
  end

  # == Instance Methods =====================================================

  def initialize(options = nil)
    @options = options || { }
    
    @task_lock = { }

    @logger = @options[:logger] || Pigeon::Logger.new(File.open(File.expand_path('engine.log', LOG_DIR), 'w+'))
    
    @logger.level = Pigeon::Logger::DEBUG if (@options[:debug])
    
    @queue = { }
    
    run_chain(:after_initialize)
  end

  def run
    run_chain(:before_start)

    STDOUT.sync = true

    @logger.info("Engine \##{id} Running")
    
    run_chain(:after_start)
  end

  def host
    Socket.gethostname
  end

  def id
    @id ||= '%8x%8x' % [ Time.now.to_i, rand(1 << 32) ]
  end
  
  # Used to periodically execute a task or block. When giving a task name,
  # a method by that name is called, otherwise a block must be supplied.
  # An interval can be specified in seconds, or will default to 1.
  def periodically_trigger_task(task_name = nil, interval = 1, &block)
    periodically(interval) do
      trigger_task(task_name, &block)
    end
  end
  
  # This acts as a lock to prevent over-lapping calls to the same method.
  # While the first call is in progress, all subsequent calls will be ignored.
  def trigger_task(task_name = nil, &block)
    task_lock(task_name || block) do
      block_given? ? yield : send(task_name)
    end
  end
  
  def task_lock(task_name)
    # NOTE: This is a somewhat naive locking mechanism that may break down
    #       when two requests are fired off within a nearly identical period.
    #       For now, this achieves a general purpose solution that should work
    #       under most circumstances. Refactor later to improve.
    
    return if (@task_lock[task_name])
    
    @task_lock[task_name] = true
    
    yield if (block_given?)
    
    @task_lock[task_name] = false
  end

  def timer(interval, &block)
    EventMachine::Timer.new(interval, &block)
  end
  
  # Periodically calls a block. No check is performed to see if the block is
  # already executing.
  def periodically(interval, &block)
    EventMachine::PeriodicTimer.new(interval, &block)
  end
  
  # Used to defer a block of work for near-immediate execution. Uses the
  # EventMachine#defer method but is not as efficient as the queue method.
  def defer(&block)
    EventMachine.defer(&block)
  end
  
  # Shuts down the engine.
  def terminate
    EventMachine.stop_event_loop
  end
  
  # Used to queue a block for immediate processing on a background thread.
  # An optional queue name can be used to sequence tasks properly.
  def queue(name = :default, &block)
    target_queue = @queue[name] ||= Pigeon::Queue.new(name == :default ? nil : 1)
    
    target_queue.perform(&block)
  end
  
  class << self
    CHAINS.each do |chain_name|
      define_method(chain_name) do |&block|
        chain_iv = :"@_#{chain_name}_chain"
        instance_variable_set(chain_iv, [ ]) unless (instance_variable_get(chain_iv))
      
        chain = instance_variable_get(chain_iv)
      
        unless (chain)
          chain = [ ]
          instance_variable_set(chain_iv, chain)
        end
      
        chain << block
      end
    end

    def run_chain(chain_name, instance)
      chain = instance_variable_get(:"@_#{chain_name}_chain")

      return unless (chain)

      chain.each do |proc|
        instance.instance_eval(&proc)
      end
    end
  end

  def debug?
    !!@options[:debug]
  end
  
  def foreground?
    !!@options[:foreground]
  end

protected
  def run_chain(chain_name)
    self.class.run_chain(chain_name, self)
  end
end
