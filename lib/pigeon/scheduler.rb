class Pigeon::Scheduler
  # == Constants ============================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Validations ==========================================================

  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  def initialize(queues, processors)
    @queues =
      case (queues)
      when Array
        { nil => queues }
      when Hash
        queues
      else
        { nil => [ queues ] }
      end

    @processors =
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
