module Pigeon::Support
  def self.daemonize
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
end
