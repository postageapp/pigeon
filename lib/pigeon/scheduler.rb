class Pigeon::Scheduler
  # == Properties ===========================================================
  
  attr_reader :queues
  attr_reader :processors

  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  # Creates a new scheduler. If queue is specified, then that queue will
  # become the default queue. One or more processors can be supplied to work
  # with this queue, though they should be supplied bound to the queue in
  # order to properly receive tasks.
  def initialize(queue = nil, *processors)
    @queues = {
      nil => queue || Pigeon::Queue.new
    }
    
    processors.flatten!
    
    @processors = processors.empty? ? [ Pigeon::Processor.new(@queues[nil]) ] : processors
  end
  
  # Adds one or more tasks to the schedule, where the tasks can be provided
  # individually, as a list, or as an array.
  def add(*tasks)
    tasks.flatten.each do |task|
      enqueue_task(task)
    end
  end
  
  # Add a single task to the schedule. When subclassing, override the private
  # enqueue_task method instead.
  def <<(task)
    enqueue_task(task)
  end

  # Returns the default queue used for scheduling.
  def default_queue
    @queues[nil]
  end

  # Used to assign the default queue.
  def default_queue=(queue)
    @queues[nil] = queue
  end
  
  # Returns the queue with the given name if one is defined, nil otherwise.
  def queue(queue_name)
    @queues[queue_name]
  end

  # Sets the scheduler running.
  def run!
    @state = :running
  end

  # Pauses the scheduler which will prevent additional tasks from being
  # initiated. Any tasks in progress will continue to run. Tasks can still
  # be added but will not be executed until the scheduler is running.
  def pause!
    @state = :paused
  end
  
  # Stops the scheduler and clears out the queue. No new tasks will be
  # accepted until the scheduler is in a paused or running state.
  def stop!
    @state = :stopped
  end
  
  # Returns true if the scheduler is running, false otherwise.
  def running?
    @state == :running
  end
  
  # Returns true if the scheduler is paused, false otherwise.
  def paused?
    @state == :paused
  end
  
  # Returns true if the scheduler is stopped, false otherwise.
  def stopped?
    @state == :stopped
  end
  
  # Returns true if there are no scheduled tasks, false otherwise.
  def empty?
    self.queue_size == 0
  end
  
  # Returns the number of tasks that have been queued up.
  def queue_length
    @queues.inject(0) do |length, (name, queue)|
      length + queue.length
    end
  end
  alias_method :queue_size, :queue_length

  # Returns the number of processors that are attached to this scheduler.
  def processors_count
    @processors.length
  end

protected
  # This method defines how to handle adding a task to the scheduler, which
  # in this case simply puts it into the default queue. Subclasses should
  # redefine this to organize tasks as required.
  def enqueue_task(task)
    default_queue << task
  end
end
