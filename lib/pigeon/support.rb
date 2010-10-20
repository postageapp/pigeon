module Pigeon::Support
  # Uses the double-fork method to create a fully detached background
  # process. Returns the process ID of the created process. May throw an
  # exception if these processes could not be created.
  def daemonize
    rfd, wfd = IO.pipe
    
    forked_pid = fork do
      daemon_pid = fork do
        yield
      end
      
      wfd.puts daemon_pid
      wfd.flush
      wfd.close
    end

    Process.wait(forked_pid)

    daemon_pid = rfd.readline
    
    daemon_pid.to_i
  end
  
  # Finds the first directory in the given list that exists and is
  # writable. Returns nil if none match.
  def find_writable_directory(*list)
    list.flatten.compact.find do |dir|
      File.exist?(dir) and File.writable?(dir)
    end
  end
    
  # Make all methods callable directly without having to include it
  extend self
end
