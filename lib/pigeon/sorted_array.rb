class Pigeon::SortedArray < Array
  # == Exceptions ===========================================================
  
  class SortArgumentRequired < Exception
  end
  
  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  # Creates a new sorted array with an optional sort method supplied as
  # a block. The sort method supplied should accept two arguments that are
  # objects in the array to be compared and should return -1, 0, or 1 based
  # on their sorting order. By default the comparison performed is <=>
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
  
  # Adds an object to the array by inserting it into the appropriate sorted
  # location directly.
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
  
  # Combines another array with this one and returns the sorted result.
  def +(array)
    self.class[*super(array).sort(&@sort_method)]
  end
end
