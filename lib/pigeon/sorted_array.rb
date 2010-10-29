class Pigeon::SortedArray < Array
  # == Exceptions ===========================================================
  
  class SortArgumentRequired < Exception
  end
  
  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  def initialize(&sort_method)
    sort_method ||= lambda { |a,b| a <=> b }
    
    @sort_method =
      case (sort_method && sort_method.arity)
      when 2
        sort_method
      when 1
        lambda { |a,b| sort_method.call(a) <=> sort_method.call(b) }
      else
        raise SortArgumentRequired
      end
  end
  
  def <<(object)
    low = 0
    high = length
    
    while (low != high)
      mid = (high + low) / 2
      
      comparison = @sort_method.call(object, at(mid))
      
      if (comparison < 0)
        high = mid
      elsif (comparison > 0)
        low = mid + 1
      else
        break
      end
    end
    
    insert(low, object)
  end
  
  def +(array)
    self.class[*super(array).sort(&@sort_method)]
  end
end
