require 'eventmachine'
require 'socket'
require 'fiber'

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
    boolean: true
  option_accessor :debug,
    boolean: true
  option_accessor :log_rotation
  option_accessor :engine_log_name,
    default: 'engine.log'
  option_accessor :engine_logger
  option_accessor :query_log_name,
    default: 'query.log'
  option_accessor :query_logger
  option_accessor :try_pid_dirs,
    default: %w[
      /var/run
      /tmp
    ].freeze
  option_accessor :try_log_dirs,
    default: %w[
      /var/log
      /tmp
    ].freeze
  option_accessor :threaded,
    boolean: true,
    default: false
    
  attr_reader :id
  attr_reader :state

  # == Constants ============================================================
  
  CHAINS = %w[
    after_initialize
    before_start
    after_start
    before_stop
    after_stop
    before_resume
    after_resume
    before_standby
    after_standby
    before_shutdown
    after_shutdown
  ].collect(&:to_sym).freeze

  # == Class Methods ========================================================
  
  # Returns the human-readable name of this engine. Defaults to the name
  # of the engine class, but can be replaced to customize a subclass.
  def self.name
    @name or self.to_s.gsub(/::/, ' ')
  end
  
  # Returns the custom process name for this engine or nil if not assigned.
  def self.process_name
    @process_name
  end
  
  # Assigns the process name. This will be applied only when the engine is
  # started.
  def self.process_name=(value)
    @process_name = value
  end

  # Returns the user this process should run as, or nil if no particular
  # user is required. This will be applied after the engine has been started
  # and the after_start call has been triggered.
  def self.user
    @user
  end
  
  # Assigns the user this process should run as, given a username.
  def self.user=(value)
    @user = value
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
    engine = nil
    
    EventMachine.run do
      engine = new(options)
      
      Signal.trap('INT') do
        engine.terminate
      end

      Pigeon::Engine.register_engine(engine)

      yield(engine) if (block_given?)

      engine.run
    end

    Pigeon::Engine.unregister_engine(engine)
  end
  
  def self.pid_file
    @pid_file ||= Pigeon::Pidfile.new(self.pid_file_path)
  end

  def self.start(options = nil)
    logger = self.engine_logger
    
    pid = Pigeon::Support.daemonize(logger) do
      launch({
        logger: logger
      }.merge(options || { }))
    end

    pid_file.create!(pid)

    yield(pid) if (block_given?)
    
    pid
  end

  def self.run
    yield($$) if (block_given?)

    launch(foreground: true)
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
      
      begin
        while (Process.kill(0, pid))
          sleep(1)
        end
      rescue Errno::ESRCH
        # No such process, already terminated
      end

      pid_file.remove!
    end
    
    pid = pid.to_i if (pid)

    yield(pid) if (block_given?)
    
    pid
  end

  def self.restart
    self.stop do |old_pid|
      self.start do |pid|
        yield(pid, old_pid) if (block_given?)
      end
    end
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
      f = File.open(File.expand_path(self.engine_log_name, self.log_dir), 'a')
      f.sync = true

      Pigeon::Logger.new(f, self.log_rotation)
    end
  end

  # Returns a default logger for queries.
  def self.query_logger
    @query_logger ||= begin
      f = File.open(File.expand_path(self.query_log_name, self.log_dir), 'a')
      f.sync = true
    
      Pigeon::Logger.new(f, self.log_rotation)
    end
  end
  
  # Returns a handle to the engine currently running, or nil if no engine is
  # currently active.
  def self.default_engine
    @engines and @engines[0]
  end

  # Registers the engine as running. The first engine running will show up
  # as the default engine.
  def self.register_engine(engine)
    @engines ||= [ ]
    @engines << engine
  end
  
  # Removes the engine from the list of running engines.
  def self.unregister_engine(engine)
    @engines.delete(engine)
  end

  def self.clear_engines!
    @engines = [ ]
  end
  
  # Schedules a block for execution on the main EventMachine thread. This is
  # a wrapper around the EventMachine.schedule method.
  def self.execute_in_main_thread(&block)
    EventMachine.next_tick(&block)
  end

  # == Instance Methods =====================================================

  def initialize(options = nil)
    @id = Pigeon::Support.unique_id

    wrap_chain(:initialize) do
      @options = options || { }
    
      @task_lock = Mutex.new
      @task_locks = { }

      @task_register_lock = Mutex.new
      @registered_tasks = { }
    
      self.logger ||= self.engine_logger
      self.logger.level = Pigeon::Logger::DEBUG if (self.debug?)
    
      @dispatcher = { }
    
      @state = :initialized
    end
  end

  # Returns the hostname of the system this engine is running on.
  def host
    Socket.gethostname
  end

  # Handles the run phase of the engine, triggers the before_start and
  # after_start events accordingly.
  def run
    assign_process_name!

    wrap_chain(:start) do
      STDOUT.sync = true

      logger.info("Engine \##{id} Running")
    
      switch_to_effective_user! if (self.class.user)

      @state = :running
    end
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
    
    @task_locks[task_name].synchronize do
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
  # wrapper around EventMachine.defer and does not perform as well as using
  # the alternate dispatch method.
  def defer(&block)
    EventMachine.defer(&block)
  end
  
  # Schedules a block for execution on the main EventMachine thread. This is
  # a wrapper around the EventMachine.schedule method.
  def execute_in_main_thread(&block)
    EventMachine.schedule(&block)
  end
  
  # Shuts down the engine. Will also trigger the before_stop and after_stop
  # events.
  def terminate
    wrap_chain(:stop) do
      EventMachine.stop_event_loop
      @state = :terminated
    end
  end
  
  # Used to dispatch a block for immediate processing on a background thread.
  # An optional queue name can be used to sequence tasks properly. The main
  # queue has a large number of threads, while the named queues default
  # to only one so they can be processed sequentially.
  def dispatch(name = :default, &block)
    if (self.threaded?)
      target_queue = @dispatcher[name] ||= Pigeon::Dispatcher.new(name == :default ? nil : 1)

      target_queue.perform(&block)
    else
      EventMachine.next_tick(&block)
    end
  end

  def resume!
    case (@state)
    when :running
      # Ignored since already running.
    when :terminated
      # Invalid operation, should produce error.
    else
      wrap_chain(:resume) do
        @state = :running
      end
    end
  end
  
  def standby!
    case (@state)
    when :standby
      # Already in standby state, ignored.
    when :terminated
      # Invalid operation, should produce error.
    else
      wrap_chain(:standby) do
        @state = :standby
      end
    end
  end
  
  def shutdown!
    case (@state)
    when :terminated
      # Already terminated, ignored.
    else
      wrap_chain(:shutdown) do
        self.terminate
      end
    end
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

    def chain_procs(chain_name)
      instance_variable_get(:"@_#{chain_name}_chain")
    end
  end

  # Returns true if the debug option was set, false otherwise.
  def debug?
    !!self.debug
  end
  
  # Returns true if running in the foreground, false otherwise.
  def foreground?
    !!self.foreground
  end
  
  # Registers a task with the engine. The given task will then be included
  # in the list returned by registered_tasks.
  def register_task(task)
    @task_register_lock.synchronize do
      @registered_tasks[task] = task
    end
  end

  # Removes a task from the list of tasks registered with this engine.
  def unregister_task(task)
    @task_register_lock.synchronize do
      @registered_tasks.delete(task)
    end
  end
  
  # Returns a list of tasks that have been registered with the engine.
  def registered_tasks
    @task_register_lock.synchronize do
      @registered_tasks.values
    end
  end

protected
  def wrap_chain(chain_name)
    Fiber.new do
      run_chain(:"before_#{chain_name}")
      yield if (block_given?)
      run_chain(:"after_#{chain_name}")
    end.resume
  end
  
  def run_chain(chain_name)
    callbacks = { }
    fiber = Fiber.current
    
    if (procs = self.class.chain_procs(chain_name))
      procs.each do |proc|
        case (proc.arity)
        when 1
          callback = lambda {
            callbacks.delete(callback)
            
            if (callbacks.empty?)
              fiber.resume
            end
          }
          
          callbacks[callback] = true

          instance_exec(callback, &proc)
        else
          instance_eval(&proc)
        end
      end
      
      if (callbacks.any?)
        Fiber.yield
      end
    end
  end
  
  def switch_to_effective_user!
    require 'etc'
    
    requested_user = Etc.getpwnam(self.class.user)
    requested_uid = (requested_user and requested_user.uid)
    
    if (Process.uid != requested_uid)
      switched_to_uid = Process::UID.change_privilege(requested_uid)
      
      unless (requested_uid == switched_to_uid)
        STDERR.puts "Could not switch to effective UID #{uid} (#{self.class.user})"
        exit(-9)
      end
    end
  end
  
  def assign_process_name!
    if (self.class.process_name)
      $0 = self.class.process_name
    end
  end
end
