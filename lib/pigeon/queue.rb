class Pigeon::Queue
  # == Constants ============================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Validations ==========================================================

  # == Class Methods ========================================================
  
  def self.filters
    @filters ||= {
      nil => lambda { |task| true }
    }
  end
  
  def self.filter(name, &block)
    filters[name] = block
  end

  # == Instance Methods =====================================================

  def initialize
    @semaphore = Mutex.new

    @tasks = [ ]
    @filters = self.class.filters.dup
    @next_task = { }
    @sort_by = :priority.to_proc
  end
  
  def sort_by(&block)
    @sort_by = block
    @semaphore.synchronize do
      @tasks = @tasks.sort_by(&@sort_by)
      
      @next_task = { }
    end
  end
  
  def filter(name, &block)
    @semaphore.synchronize do
      @filters[name] = block
      @next_task[name] = @tasks.find(&block)
    end
  end
  
  def update_filter!(name = nil)
    @semaphore.synchronize do
      @next_task[name] = @tasks.find(&block)
    end
  end
  
  def <<(task)
    @semaphore.synchronize do
      task_sort_by = @sort_by.call(task)
      insert_index = @tasks.find_index do |queued_task|
        @sort_by.call(queued_task) > task_sort_by
      end
      
      @tasks.insert(insert_index || -1, task)
      
      @next_task.each do |filter_name, next_task|
        if (!next_task and @filters[filter_name].call(task))
          @next_task[filter_name] = task
        end
      end
    end
    
    task
  end
  
  def each
    @semaphore.synchronize do
      tasks = @tasks.dup
    end
    
    tasks.each do
      yield(task)
    end
  end
  
  def peek(filter_name = nil, &block)
    if (block_given?)
      @semaphore.synchronize do
        @tasks.find(&block)
      end
    else
      @next_task[filter_name] ||= begin
        @semaphore.synchronize do
          filter_proc = @filters[filter_name] 
      
          filter_proc and @tasks.find(&filter_proc)
        end
      end
    end
  end

  def pop(filter_name = nil, &block)
    popped_task =
      if (block_given?)
        @semaphore.synchronize do
          @tasks.find(&block)
        end
      else
        peek(filter_name)
      end
    
    if (popped_task)
      @semaphore.synchronize do
        @tasks.delete(popped_task)
        
        @next_task.each do |filter_name, next_task|
          if (popped_task == next_task)
            @next_task[filter_name] = nil
          end
        end
      end
    end

    popped_task
  end
  
  def empty?(filter_name = nil, &block)
    if (block_given?)
      @semaphore.synchronize do
        !@tasks.find(&block)
      end
    else
      !peek(filter_name)
    end
  end
  
  def length(filter_name = nil, &block)
    filter_proc = @filters[filter_name] 
  
    @semaphore.synchronize do
      filter_proc ? @tasks.count(&filter_proc) : nil
    end
  end
  alias_method :count, :length
end
