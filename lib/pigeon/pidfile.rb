class Pigeon::Pidfile
  # == Constants ============================================================

  # == Properties ===========================================================
  
  attr_reader :path 
  
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================
  
  def initialize(path)
    @path = path
    
    @path += '.pid' unless (@path.match(/\./))
  end
  
  def running?
    !!self.running
  end
  
  def running
    pid = self.saved_pid

    (pid and Process.kill(0, pid)) ? pid : nil
  rescue Errno::ESRCH
    nil
  end
  
  def saved_pid
    File.read(@path).to_i
  rescue Errno::ENOENT
    nil
  end
  
  def create!(pid = nil)
    open(@path, 'w') do |fh|
      fh.puts(pid || $$)
    end
  end
  
  def remove!
    return unless (exist?)

    File.unlink(@path)
  end
  
  def exist?
    File.exist?(@path)
  end
end
