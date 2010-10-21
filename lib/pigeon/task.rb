class Pigeon::Task
  # == Constants ============================================================
  
  # == Properties ===========================================================
  
  attr_reader :state
  attr_reader :exception

  # == Class Methods ========================================================

  # Defines the initial state of this type of task. Default is :initialized
  # but this can be customized in a subclass.
  def self.initial_state
    :initialized
  end
  
  # Returns an array of the terminal states for this task. Default is
  # :failed, :finished but this can be customized in a subclass.
  def self.terminal_states
    [ :failed, :finished ].freeze
  end

  # == Instance Methods =====================================================
  
  def initialize(engine)
    @engine = engine
    
    after_initialized
  end
  
  # Kicks off the task. An optional callback is executed just before each
  # state is excuted and is passed the state name as a symbol.
  def run!(&callback)
    @callback = callback if (block_given?)
    
    @state = self.class.initial_state

    run_state!
  end

  # Returns true if the task is in the finished state, false otherwise.
  def finished?
    @state == :finished
  end

  # Returns true if the task is in the failed state, false otherwise.
  def failed?
    @state == :failed
  end
  
  # Returns true if an exception was thrown, false otherwise.
  def exception?
    !!@exception
  end
  
  # Returns true if the task is in any terminal state.
  def terminal_state?
    self.class.terminal_states.include?(@state)
  end
  
  # Dispatches a block to be run as soon as possible.
  def dispatch(&block)
    @engine.dispatch(&block)
  end
  
  # Returns a numerical priority order. If redefined in a subclass,
  # should return a comparable value.
  def priority
    @priority ||= Time.now.to_f
  end
  
  # Ranks tasks by priority.
  def <=>(task)
    self.priority <=> task.priority
  end
  
protected
  def run_state!
    current_state = @state

    before_state(current_state)

    if (@callback)
      case (@callback.arity)
      when 2
        @callback.call(self, current_state)
      when 1
        @callback.call(current_state)
      else
        @callback.call
      end
    end

    unless (self.terminal_state?)
      state_method = :"state_#{@state}!"

      # Only perform this state action if it is defined, otherwise ignore
      # as some states may be deliberately NOOP in order to wait for some
      # action to be completed asynchronously.
      if (respond_to?(state_method))
        send(state_method)
      end
    end
    
  rescue Object => e
    @exception = e

    handle_exception(e) rescue nil
    
    transition_to_state(:failed) unless (self.failed?)
    
    after_failed
  ensure
    after_state(current_state)

    if (self.class.terminal_states.include?(current_state))
      self.after_finished
    end
  end

  # Schedules the next state to be executed. This method should only be
  # called once per state or it may result in duplicated state actions.
  def transition_to_state(state)
    @state = state

    @engine.dispatch do
      run_state!
    end
    
    @state
  end
  
  # Called just after the task is initialized.
  def after_initialized
  end
  
  # Called before a particular state is executed.
  def before_state(state)
  end

  # Called after a particular state is executed.
  def after_state(state)
  end

  # Called just after the task is finished.
  def after_finished
  end

  # Called just after the task fails.
  def after_failed
  end

  # Called when an exception is thrown during processing with the exception
  # passed as the first argument. Default behavior is to do nothing but
  # this can be customized in a subclass. Any exceptions thrown by this
  # method are ignored.
  def handle_exception(exception)
  end
  
  # This defines the behaivor of the intialized state. By default this
  # simply transitions to the finished state.
  def state_initialized!
    transition_to_state(:finished)
  end
end
