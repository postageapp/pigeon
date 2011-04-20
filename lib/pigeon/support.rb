require 'digest/sha1'

module Pigeon::Support
  # Uses the double-fork method to create a fully detached background
  # process. Returns the process ID of the created process. May throw an
  # exception if these processes could not be created.
  def daemonize(logger = nil)
    delay = 10
    rfd, wfd = IO.pipe
    
    forked_pid = fork do
      rfd.close

      supervisor_pid = fork do
        relaunch = true
        
        while (relaunch)
          daemon_pid = fork do
            begin
              yield
            rescue Object => e
              if (logger)
                logger.error("Terminated with Exception: [#{e.class}] #{e}")
                logger.error(e.backtrace.join("\n"))

                Thread.list.each do |thread|
                  logger.error("Stack trace of current threads")
                  logger.error(thread.inspect)
                  
                  if (thread.backtrace)
                    logger.error("\t" + thread.backtrace.join("\n\t"))
                  end
                end
              end
            end
          end
          
          begin
            Process.wait(daemon_pid)

            # A non-zero exit status indicates some sort of error, so the
            # process will be relaunched after a short delay.
            relaunch = ($? != 0)

          rescue Interrupt
            relaunch = false
          end
          
          if (relaunch)
            logger.info("Will relaunch in %d seconds" % delay)

            sleep(delay)
          else
            logger.info("Terminated normally")
          end
        end
      end

      wfd.puts(supervisor_pid)
      
      wfd.flush
      wfd.close
    end

    wfd.close

    Process.wait(forked_pid)

    daemon_pid = rfd.readline
    rfd.close
    
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
  # a particular instance was launched. For informational purposes, the name
  # of the host is appended to help identify the origin of the ident.
  def unique_id
    '%8x%s@%s' % [
      Time.now.to_i,
      Digest::SHA1.hexdigest(
        '%.8f%8x' % [ Time.now.to_f, rand(1 << 32) ]
      )[0, 32],
      Socket.gethostname
    ]
  end

  # Make all methods callable directly without having to include it
  extend self
end
