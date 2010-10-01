require 'logger'

class Pigeon::Logger < Logger
  # Returns a sequential thread identifier which is human readable and much
  # more concise than internal numbering system used.
  def thread_id
    @threads ||= { }
    @threads[Thread.current.object_id] ||= @threads.length
  end
  
  # Over-rides the default log format.
  def format_message(severity, datetime, progname, msg)
    "[%s %6d] %s\n" % [ datetime.strftime("%Y-%m-%d %H:%M:%S"), thread_id, msg ]
  end
end
