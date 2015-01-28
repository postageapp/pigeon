require 'thwait'

class Pigeon::Dispatcher
  # == Extensions ===========================================================
  
  extend Pigeon::OptionAccessor

  # == Constants ============================================================

  # == Properties ===========================================================
  
  option_accessor :thread_limit,
    default: 24

  attr_reader :exceptions

  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  # Creates a new instance of a dispatcher. An optional limit parameter is
  # used to specify how many threads can be used, which if nil will use the
  # concurrency_limit established for the class.
  def initialize(limit = nil)
    @thread_limit = limit
    @backlog = [ ]
    @threads = [ ]
    @exceptions = [ ]
    @sempaphore = Mutex.new
  end
  
  def perform(*args, &block)
    @backlog << [ block, args, caller(0) ]

    @sempaphore.synchronize do
      if (@threads.length < self.thread_limit and @threads.length < @backlog.length)
        create_thread
      end
    end
  end
  
  # Returns true if there are no operations in the backlog queue or running,
  # false otherwise.
  def empty?
    @backlog.empty? and @threads.empty?
  end
  
  # Returns true if any exceptions have been generated, false otherwise.
  def exceptions?
    !@exceptions.empty?
  end

  # Returns the number of items in the backlog queue.
  def backlog_size
    @backlog.length
  end
  
  # Returns the current number of threads executing.
  def thread_count
    @threads.length
  end
  
  # Waits until all operations have completed, including the backlog.
  def wait!
    while (!@threads.empty?)
      ThreadsWait.new(@threads).join
    end
  end
  
protected
  def create_thread
    @threads << Thread.new do
      Thread.current.abort_on_exception = true
    
      begin
        while (block = @backlog.pop)
          begin
            block[0].call(*block[1])
          rescue Object => e
            puts "#{e.class}: #{e} #{e.backtrace.join("\n")}"
            @exceptions << e
          end
        
          Thread.pass
        end
      ensure
        @sempaphore.synchronize do
          @threads.delete(Thread.current)
        end
      end
    end
  end
end
