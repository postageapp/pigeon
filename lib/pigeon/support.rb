require 'digest/sha1'

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
    
  # Returns a unique 160-bit identifier for this engine expressed as a 40
  # character hexadecimal string. The first 32-bit sequence is a timestamp
  # so these numbers increase over time and can be used to identify when
  # a particular instance was launched.
  def unique_id
    '%8x%s' % [
      Time.now.to_i,
      Digest::SHA1.hexdigest(
        '%.8f%8x' % [ Time.now.to_f, rand(1 << 32) ]
      )[0, 32]
    ]
  end

  # Make all methods callable directly without having to include it
  extend self
end
