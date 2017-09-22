require_relative '../helper'

class PigeonSortedArrayTest < Minitest::Test
  def test_empty_state
    array = Pigeon::SortedArray.new
    
    assert array.empty?
    assert array.is_a?(Array)
    assert_equal [ ], array
    
    dup = array.dup
    
    assert_equal Pigeon::SortedArray, dup.class
    
    combined = (array + array)
    
    assert_equal [ ], combined
    assert_equal Pigeon::SortedArray, combined.class
  end
  
  def test_does_sorting
    array = Pigeon::SortedArray.new
    
    test_array = [ 2, 2, 2, 2, 3, 3, 3 ]
    
    test_array.each do |i| 
      array << i
    end
    
    assert_equal [ 2, 2, 2, 2, 3, 3, 3 ], array.to_a
  end
  
  def test_does_sorting_with_insertion_in_order
    array = Pigeon::SortedArray.new

    10.times do |n|
      array << n.to_f
    end
    
    assert_equal (0..9).to_a.collect(&:to_f), array
  end

  def test_does_sorting_with_insertion_random_order
    array = Pigeon::SortedArray.new
    
    srand
    (0..10000).to_a.sort_by { rand }.each do |i|
      array << i
    end
  
    assert_equal (0..10000).to_a, array
    assert_equal 10001, array.length
  end
end
