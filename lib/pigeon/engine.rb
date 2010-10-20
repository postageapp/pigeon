require 'eventmachine'
require 'socket'
require 'digest/sha1'

class Pigeon::Engine
  # == Submodules ===========================================================

  class RuntimeError < Exception
  end
  
  class ConfigurationError < Exception
  end
  
  # == Extensions ==========================================================
  
  extend Pigeon::OptionAccessor
  
  # == Properties ===========================================================
  
  option_accessor :logger

  option_accessor :name
  option_accessor :pid_file_name
  option_accessor :foreground,
    :boolean => true
  option_accessor :debug,
    :boolean => true
    
  option_accessor :engine_log_name,
    :default => 'engine.log'
  option_accessor :engine_logger

  option_accessor :query_log_name,
    :default => 'query.log'
  option_accessor :query_logger
  
  option_accessor :try_pid_dirs,
    :default => %w[
      /var/run
      /tmp
    ].freeze

  option_accessor :try_log_dirs,
    :default => %w[
      /var/log
      /tmp
    ].freeze

  # == Constants ============================================================
  
  CHAINS = %w[
    after_initialize
    before_start
    after_start
    before_stop
    after_stop
  ].collect(&:to_sym).freeze

  # == Class Methods ========================================================
  
  # Returns the human-readable name of this engine. Defaults to the name
  # of the engine class, but can be replaced to customize a subclass.
  def self.name
    @name or self.to_s.gsub(/::/, ' ')
  end
  
  # Returns the name of the PID file to use. The full path to the file
  # is specified elsewhere.
  def self.pid_file_name
    @pid_file_name or self.name.downcase.gsub(/ /, '-') + '.pid'
  end
  
  # Returns the full path to the PID file that should be used to track
  # the running status of this engine.
  def self.pid_file_path
    @pid_file_path ||= begin
      if (path = Pigeon::Support.find_writable_directory(self.try_pid_dirs))
        File.expand_path(self.pid_file_name, path)
      else
        raise ConfigurationError, "Could not find a writable directory for the PID file in: #{self.try_pid_dirs.join(' ')}"
      end
    end
  end

  # Returns the full path to the directory used to store logs.
  def self.log_dir
    @log_file_path ||= Pigeon::Support.find_writable_directory(self.try_log_dirs)
  end
  
  # Launches the engine with the specified options
  def self.launch(options = nil)
    EventMachine.run do
      engine = new(options)
      
      yield(engine) if (block_given?)
    
      Signal.trap('INT') do
        engine.terminate
      end

      engine.run
    end
  end
  
  def self.pid_file
    @pid_file ||= Pigeon::Pidfile.new(self.pid_file_path)
  end

  def self.start(options = nil)
    pid = Pigeon::Support.daemonize do
      launch(options)
    end

    pid_file.create!(pid)

    yield(pid) if (block_given?)
    
    pid
  end

  def self.run
    yield($$) if (block_given?)

    launch(:foreground => true)
  end
  
  def self.stop
    pid = self.pid_file.running
    
    if (pid)
      begin
        Process.kill('INT', pid)
      rescue Errno::ESRCH
        # No such process exception
        pid = nil
      end

      pid_file.remove!
    end
    
    pid = pid.to_i if (pid)

    yield(pid) if (block_given?)
    
    pid
  end

  def self.restart
    self.stop
    self.start
  end
  
  def self.running?
    pid_file.running
  end
  
  def self.status
    pid = pid_file.running
    
    yield(pid) if (block_given?)
    
    pid
  end
  
  # Returns a default logger for the engine.
  def self.engine_logger
    @engine_logger ||= begin
      f = File.open(File.expand_path(self.engine_log_name, self.log_dir), 'w+')
      f.sync = true

      Pigeon::Logger.new(f)
    end
  end

  # Returns a default logger for queries.
  def self.query_logger
    @query_logger ||= begin
      f = File.open(File.expand_path(self.query_log_name, self.log_dir), 'w+')
      f.sync = true
    
      Pigeon::Logger.new(f)
    end
  end

  # == Instance Methods =====================================================

  def initialize(options = nil)
    @options = options || { }
    
    @task_lock = Mutex.new
    @task_locks = { }

    self.logger ||= self.engine_logger
    self.logger.level = Pigeon::Logger::DEBUG if (self.debug?)
    
    @queue = { }
    
    run_chain(:after_initialize)
  end

  # Returns the hostname of the system this engine is running on.
  def host
    Socket.gethostname
  end

  # Returns a unique 160-bit identifier for this engine expressed as a 40
  # character hexadecimal string. The first 32-bit sequence is a timestamp
  # so these numbers increase over time and can be used to identify when
  # a particular instance was launched.
  def id
    @id ||= '%8x%s' % [
      Time.now.to_i,
      Digest::SHA1.hexdigest(
        '%.8f%8x' % [ Time.now.to_f, rand(1 << 32) ]
      )[0, 32]
    ]
  end

  # Handles the run phase of the engine, triggers the before_start and
  # after_start events accordingly.
  def run
    run_chain(:before_start)

    STDOUT.sync = true

    logger.info("Engine \##{id} Running")
    
    run_chain(:after_start)
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
  
  # This is a somewhat naive locking mechanism that may break down
  # when two requests are fired off within a nearly identical period.
  # For now, this achieves a general purpose solution that should work
  # under most circumstances. Refactor later to improve.
  def task_lock(task_name)
    @task_lock.synchronize do
      @task_locks[task_name] ||= Mutex.new
    end
    
    return if (@task_locks[task_name].locked?)
    
    @task_lock[task_name].synchronize do
      yield if (block_given?)
    end
  end

  def timer(interval, &block)
    EventMachine::Timer.new(interval, &block)
  end
  
  # Periodically calls a block. No check is performed to see if the block is
  # already executing.
  def periodically(interval, &block)
    EventMachine::PeriodicTimer.new(interval, &block)
  end
  
  # Used to defer a block of work for near-immediate execution. Is a 
  # wrapper around EventMachine#defer and does not perform as well as using
  # the alternate queue method.
  def defer(&block)
    EventMachine.defer(&block)
  end
  
  # Shuts down the engine. Will also trigger the before_stop and after_stop
  # events.
  def terminate
    run_chain(:before_stop)

    EventMachine.stop_event_loop

    run_chain(:after_stop)
  end
  
  # Used to queue a block for immediate processing on a background thread.
  # An optional queue name can be used to sequence tasks properly. The main
  # queue has a large number of threads, while the named queues default
  # to only one so they can be processed sequentially.
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

  # Returns true if the debug option was set, false otherwise.
  def debug?
    !!@options[:debug]
  end
  
  # Returns true if running in the foreground, false otherwise.
  def foreground?
    !!@options[:foreground]
  end

protected
  def run_chain(chain_name)
    self.class.run_chain(chain_name, self)
  end
end
