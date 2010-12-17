class Pigeon::Processor
  # == Exceptions ===========================================================
  
  # == Constants ============================================================

  # == Properties ===========================================================
  
  attr_accessor :context
  attr_reader :queue
  attr_reader :task
  attr_reader :id

  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  # Creates a new processor. An optional queue can be specified in which case
  # the processor will register itself as an observer of that queue. A block
  # can be given to filter the tasks contained in the associated queue.
  def initialize(queue = nil, context = nil, &filter)
    @id = Pigeon::Support.unique_id
    @lock = Mutex.new
    @filter = filter || lambda { |task| true }
    @context = context
    
    if (queue)
      self.queue = queue
    
      switch_to_next_task!
    end
  end
  
  # Assigns this processor to a particular queue. If one is already assigned
  # then the observer callback for that queue will be removed.
  def queue=(queue)
    if (@queue)
      @queue.remove_processor(self, &@claim)
    end
    
    if (@queue = queue)
      @claim = lambda do |task|
        @lock.synchronize do
          if (!@task and @filter.call(task))
            @task = queue.claim(task)
      
            @task.run!(self) do
              switch_to_next_task!
            end
          end
        end
      end

      @queue.add_processor(self, &@claim)
    end
  end
  
  # Returns true if the given task would be accepted by the filter defined
  # for this processor.
  def accept?(task)
    @filter.call(task)
  end
  
  # Returns true if a task is currently being processed, false otherwise.
  def task?
    !!@task
  end
  
  def inspect
    "<#{self.class}\##{@id} queue=#{@queue.inspect} task=#{@task} context=#{@context}>"
  end
  
protected
  def switch_to_next_task!
    @lock.synchronize do
      if (@task)
        @task.processor = nil
      end
      
      @task = nil
      
      if (@queue)
        if (@task = @queue.pop(&@filter))
          @task.run!(self) do
            switch_to_next_task!
          end
        end
      end
    end
  end
end
