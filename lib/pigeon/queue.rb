require 'monitor'

class Pigeon::Queue
  # == Constants ============================================================
  
  # == Exceptions ===========================================================

  class BlockRequired < Exception
  end
  
  class TaskNotQueued < Exception
    def initialize(task = nil)
      @task = task
    end
    
    def inspect
      "Task #{@task.inspect} not queued."
    end
    alias_method :to_s, :inspect
  end

  # == Properties ===========================================================
  
  attr_reader :processors

  # == Class Methods ========================================================
  
  # Returns the current filter configuration. This is stored as a Hash with
  # the key being the filter name, the value being the matching block. The
  # nil key is the default filter which accepts all tasks.
  def self.filters
    @filters ||= {
      nil => lambda { |task| true }
    }
  end
  
  # Defines a new filter with the given name and uses the supplied block to
  # evaluate if a task qualifies or not.
  def self.filter(name, &block)
    filters[name] = block
  end

  # == Instance Methods =====================================================

  # Creates a new queue. If a block is given, it is used to compare two tasks
  # and order them, so it should take two arguments and return the relative
  # difference (-1, 0, 1) like Array#sort would work.
  def initialize(&block)
    @filters = self.class.filters.dup
    @filters.extend(MonitorMixin)
    @observers = { }
    @observers.extend(MonitorMixin)
    @claimable_task = { }
    @processors = [ ]
    @next_task = { }
    
    if (block_given?)
      @sort_by = block
    else
      @sort_by = lambda { |a,b| a.priority <=> b.priority }
    end

    @tasks = Pigeon::SortedArray.new(&@sort_by)
  end
  
  # Returns the contents sorted by the given block. The block will be passed
  # a single Task and the results are sorted by the return value.
  def sort_by(&block)
    raise BlockRequired unless (block_given?)

    @sort_by = block
    @filters.synchronize do
      @tasks = Pigeon::SortedArray.new(&@sort_by) + @tasks
      
      @next_task = { }
    end
  end
  
  # Sets up a callback for the queue that will execute the block if new tasks
  # are added to the queue. If filter_name is specified, this block will be
  # run for tasks matching that filtered subset.
  def observe(filter_name = nil, &block)
    raise BlockRequired unless (block_given?)
    
    @observers.synchronize do
      set = @observers[filter_name] ||= [ ]

      set << block
    end

    task = assign_next_task(filter_name)
  end
  
  # Removes references to the callback function specified. Note that the same
  # Proc must be passed in, as a block with an identical function will not
  # be considered equivalent.
  def remove_observer(filter_name = nil, &block)
    @observers.synchronize do
      set = @observers[filter_name]

      set and set.delete(block)
    end
  end
  
  # Adds a processor to the queue and adds an observer claim method.
  def add_processor(processor, &claim)
    @observers.synchronize do
      @processors << processor
    end

    observe(&claim) if (claim)
  end
  
  # Removes a processor from the queue and removes an observer claim method.
  def remove_processor(processor, &claim)
    @observers.synchronize do
      @processors.delete(processor)
    end

    remove_observer(&claim) if (claim)
  end
  
  # Creates a named filter for the queue using the provided block to select
  # the tasks which should match.
  def filter(filter_name, &block)
    raise BlockRequired unless (block_given?)

    @filters.synchronize do
      @filters[filter_name] = block
    end
    
    assign_next_task(filter_name)
  end
  
  # Adds a task to the queue.
  def <<(task)
    unless (task.is_a?(Pigeon::Task))
      raise "Cannot add task of class #{task.class} to #{self.class}"
    end
    
    # If there is an insert operation already in progress, put this task in
    # the backlog for subsequent processing.
    
    Pigeon::Engine.execute_in_main_thread do
      self.execute_add_task!(task)
    end
    
    task
  end

  def execute_add_task!(task)
    # Set the claimable task flag for this task since it is not yet in the
    # actual task queue.
    @claimable_task[task] = true
  
    unless (@observers.empty?)
      @observers.synchronize do
        @observers.each do |filter_name, list|
          # Check if this task matches the filter restrictions, and if it
          # does then call the observer chain in order.
          if (@filters[filter_name].call(task))
            @observers[filter_name].each do |proc|
              case (proc.arity)
              when 2
                proc.call(self, task)
              else
                proc.call(task)
              end

              # An observer callback has the opportunity to claim a task,
              # and if it does, the claimable task flag will be false. Loop
              # only while the task is claimable.
              break unless (@claimable_task[task])
            end
          end
        end
      end
    end

    # If this task wasn't claimed by an observer then insert it in the
    # main task queue.
    if (@claimable_task.delete(task))
      @filters.synchronize do
        @tasks << task
        
        # Update the next task slots for all of the unassigned filters and
        # trigger observer callbacks as required.
        @next_task.each do |filter_name, next_task|
          next if (next_task)
          
          if (@filters[filter_name].call(task))
            @next_task[filter_name] = task
          end
        end
      end
    end
  end
  
  # Iterates over each of the tasks in the queue.
  def each
    @filters.synchronize do
      tasks = @tasks.dup
    end
    
    tasks.each do
      yield(task)
    end
  end
  
  # Peeks at the next task in the queue, or if filter_name is provided,
  # then the next task meeting those filter conditions. An optional block
  # can also be used to further restrict the qualifying tasks.
  def peek(filter_name = nil, &block)
    if (block_given?)
      @filters.synchronize do
        @tasks.find(&block)
      end
    elsif (filter_name)
      @next_task[filter_name] ||= begin
        @filters.synchronize do
          filter_proc = @filters[filter_name]
      
          filter_proc and @tasks.find(&filter_proc)
        end
      end
    else
      @filters.synchronize do
        @tasks.first
      end
    end
  end
  
  # Removes all tasks from the queue. If a filter_name is given, then will
  # only remove tasks matching that filter's conditions. An optional block
  # can also be used to further restrict the qualifying tasks.
  def pull(filter_name = nil, &block)
    if (!block_given? and filter_name)
      block = @filters[filter_name]
    end
    
    @filters.synchronize do
      tasks = block ? @tasks.select(&block) : @tasks

      @tasks -= tasks
      
      @next_task.each do |filter_name, next_task|
        if (tasks.include?(@next_task[filter_name]))
          @next_task[filter_name] = nil
        end
      end
      
      tasks
    end
  end

  # Returns the next task from the queue. If a filter_name is given, then will
  # only select tasks matching that filter's conditions. An optional block
  # can also be used to further restrict the qualifying tasks. The task will
  # be removed from the queue and must be re-inserted if it is to be scheduled
  # again.
  def pop(filter_name = nil, &block)
    @filters.synchronize do
      task =
        if (block_given?)
          @tasks.find(&block)
        elsif (filter_name)
          @next_task[filter_name] || begin
            filter_proc = @filters[filter_name]

            filter_proc and @tasks.find(&filter_proc)
          end
        else
          @tasks.first
        end
    
      if (task)
        @tasks.delete(task)

        @next_task.each do |filter_name, next_task|
          if (task == next_task)
            @next_task[filter_name] = nil
          end
        end
      end

      task
    end
  end
  
  # Claims a task. This is used to indicate that the task will be processed
  # without having to be inserted into the queue.
  def claim(task)
    @filters.synchronize do
      if (@claimable_task[task])
        @claimable_task[task] = false
      elsif (@tasks.delete(task))
        @next_task.each do |filter_name, next_task|
          if (task == next_task)
            @next_task[filter_name] = nil
          end
        end
      else
        raise TaskNotQueued, task
      end
    end
      
    task
  end

  # Returns true if the task is queued, false otherwise.
  def include?(task)
    @filters.synchronize do
      @tasks.include?(task)
    end
  end
  
  # Returns true if the queue is empty, false otherwise. If filter_name is
  # given, then will return true if there are no matching tasks, false
  # otherwise. An optional block can further restrict qualifying tasks.
  def empty?(filter_name = nil, &block)
    if (block_given?)
      @filters.synchronize do
        !@tasks.find(&block)
      end
    else
      !peek(filter_name)
    end
  end
  
  # Returns the number of entries in the queue. If filter_name is given, then
  # will return the number of matching tasks. An optional block can further
  # restrict qualifying tasks.
  def length(filter_name = nil, &block)
    filter_proc = @filters[filter_name] 
  
    @filters.synchronize do
      filter_proc ? @tasks.count(&filter_proc) : nil
    end
  end
  alias_method :size, :length
  alias_method :count, :length
  
  # Copies the list of queued tasks to a new Array.
  def to_a
    @filters.synchronize do
      @tasks.dup
    end
  end
  
protected
  def assign_next_task(filter_name)
    filter = @filters[filter_name]

    return unless (filter)
    
    if (task = @next_task[filter_name])
      return task
    end
    
    @filters.synchronize do
      @next_task[filter_name] ||= @tasks.find(&filter)
    end
  end
end
