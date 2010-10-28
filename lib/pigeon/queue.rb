class Pigeon::Queue
  # == Constants ============================================================
  
  # == Exceptions ===========================================================
  
  class TaskNotQueued < Exception
  end

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
    @filter_lock = Mutex.new
    @observer_lock = Mutex.new

    @tasks = [ ]
    @claimable_task = { }
    @filters = self.class.filters.dup
    @observers = { }
    @next_task = { }
    @sort_by = :priority.to_proc
  end
  
  def sort_by(&block)
    @sort_by = block
    @filter_lock.synchronize do
      @tasks = @tasks.sort_by(&@sort_by)
      
      @next_task = { }
    end
  end
  
  def observe(filter_name = nil, &block)
    @filter_lock.synchronize do
      @observers[filter_name] ||= [ ]
      @observers[filter_name] << block
    end
  end
  
  def filter(name, &block)
    @filter_lock.synchronize do
      @filters[name] = block
      @next_task[name] = @tasks.find(&block)
    end
  end
  
  def update_filter!(name = nil)
    @filter_lock.synchronize do
      @next_task[name] = @tasks.find(&block)
    end
  end
  
  def <<(task)
    @observer_lock.synchronize do
      @filter_lock.synchronize do
        @claimable_task[task] = true
      end
      
      @observers.each do |filter_name, list|
        if (@filters[filter_name].call(task))
          list.each do |proc|
            case (proc.arity)
            when 2
              proc.call(self, task)
            else
              proc.call(task)
            end

            break unless (@claimable_task[task])
          end
        end
      end

      @filter_lock.synchronize do
        unless (@claimable_task.delete(task))
          return task
        end
      end
    end

    @filter_lock.synchronize do
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
    @filter_lock.synchronize do
      tasks = @tasks.dup
    end
    
    tasks.each do
      yield(task)
    end
  end
  
  def peek(filter_name = nil, &block)
    if (block_given?)
      @filter_lock.synchronize do
        @tasks.find(&block)
      end
    else
      @next_task[filter_name] ||= begin
        @filter_lock.synchronize do
          filter_proc = @filters[filter_name] 
      
          filter_proc and @tasks.find(&filter_proc)
        end
      end
    end
  end
  
  def pull(filter_name = nil, &block)
    unless (block_given?)
      block = @filters[filter_name]
    end
    
    @filter_lock.synchronize do
      tasks = @tasks.select(&block)
      
      @tasks -= tasks
      
      @next_task.each do |filter_name, next_task|
        if (tasks.include?(@next_task[filter_name]))
          @next_task[filter_name] = nil
        end
      end
      
      tasks
    end
  end

  def pop(filter_name = nil, &block)
    popped_task =
      if (block_given?)
        @filter_lock.synchronize do
          @tasks.find(&block)
        end
      else
        peek(filter_name)
      end
    
    if (popped_task)
      claim(popped_task)
    end

    popped_task
  end
  
  def claim(task)
    @filter_lock.synchronize do
      if (@claimable_task[task])
        @claimable_task[task] = false
        return task
      end

      deleted_task = @tasks.delete(task)
      
      if (deleted_task)
        @next_task.each do |filter_name, next_task|
          if (task == next_task)
            @next_task[filter_name] = nil
          end
        end
      else
        raise TaskNotQueued, task
      end
      
      deleted_task
    end
  end
  
  def empty?(filter_name = nil, &block)
    if (block_given?)
      @filter_lock.synchronize do
        !@tasks.find(&block)
      end
    else
      !peek(filter_name)
    end
  end
  
  def length(filter_name = nil, &block)
    filter_proc = @filters[filter_name] 
  
    @filter_lock.synchronize do
      filter_proc ? @tasks.count(&filter_proc) : nil
    end
  end
  alias_method :count, :length
end
