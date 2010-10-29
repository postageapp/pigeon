class Pigeon::Processor
  # == Constants ============================================================

  # == Properties ===========================================================
  
  attr_reader :task

  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  def initialize(queue, &filter)
    @lock = Mutex.new
    @filter = filter || lambda { |task| true }
    @queue = queue
    
    switch_to_next_task!
    
    @queue.observe do |task|
      @lock.synchronize do
        if (!@task and @filter.call(task))
          @task = queue.claim(task)
      
          @task.run! do
            switch_to_next_task!
          end
        end
      end
    end
  end
  
  def accept?(task)
    @filter.call(task)
  end
  
  def task?
    !!@task
  end
  
protected
  def switch_to_next_task!
    @lock.synchronize do
      @task = nil

      if (@task = @queue.pop(&@filter))
        @task.run! do
          switch_to_next_task!
        end
      end
    end
  end
end
