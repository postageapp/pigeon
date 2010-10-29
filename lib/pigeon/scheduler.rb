class Pigeon::Scheduler
  # == Properties ===========================================================
  
  attr_reader :queues
  attr_reader :processors

  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  def initialize(queue = nil, *processors)
    @queues = {
      nil => queue || Pigeon::Queue.new
    }
    
    processors.flatten!
    
    @processors = processors.empty? ? [ Pigeon::Processor.new(@queues[nil]) ] : processors
  end
  
  def default_queue
    @queues[nil]
  end

  def default_queue=(queue)
    @queues[nil] = queue
  end
  
  def queue(queue_name)
    @queues[queue_name]
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
end
