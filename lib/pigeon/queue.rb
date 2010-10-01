class Pigeon::Queue
  # == Constants ============================================================

  DEFAULT_CONCURRENCY_LIMIT = 24

  # == Properties ===========================================================

  attr_reader :exceptions

  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  def initialize(limit = nil)
    @limit = limit || DEFAULT_CONCURRENCY_LIMIT
    @blocks = [ ]
    @threads = [ ]
    @exceptions = [ ]
  end
  
  def perform(*args, &block)
    @blocks << [ block, args, caller(0) ]

    if (@threads.length < @limit and @threads.length < @blocks.length)
      create_thread
    end
  end
  
  def empty?
    @blocks.empty? and @threads.empty?
  end
  
  def exceptions?
    !@exceptions.empty?
  end

  def length
    @blocks.length
  end
  
  def threads
    @threads.length
  end
  
protected
  def create_thread
    @threads << Thread.new do
      Thread.current.abort_on_exception = true
      
      begin
        while (block = @blocks.pop)
          begin
            block[0].call(*block[1])
          rescue Object => e
            puts "#{e.class}: #{e} #{e.backtrace.join("\n")}"
            @exceptions << e
          end
          
          Thread.pass
        end
      ensure
        @threads.delete(Thread.current)
      end
    end
  end
end
