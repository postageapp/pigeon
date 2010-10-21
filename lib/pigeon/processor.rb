class Pigeon::Processor
  # == Constants ============================================================

  # == Constants ============================================================

  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  def initialize
    @semaphore = Mutex.new

    @queued_tasks = [ ]
    @active_tasks = { }
    
    @state = :running

    @limits = [ ]
    
    yield(self) if (block_given?)
  end
  
  # Adds a task to the backlog. Will be processed in priority order if
  # there is at least one available processor.
  def <<(task)
    @semaphore.synchronize do
      if (@active_tasks.length < )
      @queued_tasks << task
    end
  end
  alias_method :push, :<<
  
  def remove(*tasks)
    @semaphore.synchronize do
      @queued_tasks.delete(*tasks)
    end
  end
  
  def empty?
    @queued_tasks.empty? and @active_tasks.empty?
  end
  
  def run!
    @state = :running
  end
  
  def pause!
    @state = :paused
  end
  
  def stop!
    @state = :stopped
  end
  
  def running?
    @state == :running
  end
  
  def paused?
    @state == :paused
  end
  
  def stopped?
    @state == :stopped
  end
  
  def queue_size
    @queued_tasks.length
  end

  def processors_count
    @processors.length
  end
  
  def limit(count, &block)
    if (block_given?)
      @limits << [ count, block, @active_tasks.count(&block) ]
    else
      @limits << [ count, lambda { true }, @active_tasks.count, :default ]
    end
  end
end
