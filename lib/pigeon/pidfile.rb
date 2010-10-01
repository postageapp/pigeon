class Pigeon::Pidfile
  # == Constants ============================================================
  
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================
  
  def initialize(path)
    @path = path
    
    @path += '.pid' unless (@path.match(/\./))
  end
  
  def contents
    File.read(@path).to_i
  rescue Errno::ENOENT
    nil
  end
  
  def create!(pid = nil)
    open(@path, 'w') do |fh|
      fh.puts pid || $$
    end
  end
  
  def remove!
    return unless (exists?)

    File.unlink(@path)
  end
  
  def exists?
    File.exist?(@path)
  end
end
