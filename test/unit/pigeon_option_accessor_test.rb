require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class OptionClass
  extend Pigeon::OptionAccessor

  option_accessor :single_option
  option_accessor :multi1, :multi2
  option_accessor :option_with_default,
    default: :example_default

  option_accessor :boolean_option,
    boolean: true

  self.single_option = :single_option_default
end

class OptionSubclass < OptionClass
end

class PigeonOptionAccessorTest < Minitest::Test
  def test_class_and_instance_chaining
    assert_equal :single_option_default, OptionClass.single_option
    
    instance = OptionClass.new
    
    assert_equal :single_option_default, instance.single_option
    
    OptionClass.single_option = :new_default
    
    assert_equal :new_default, instance.single_option
    
    instance.single_option = :override
    
    assert_equal :override, instance.single_option
    assert_equal :new_default, OptionClass.single_option
    
    # Reset to defaults for next test
    OptionClass.single_option = :single_option_default
  end
  
  def test_subclass_inheritance
    assert_equal :single_option_default, OptionSubclass.single_option
    
    OptionSubclass.single_option = :subclass_default
    
    assert_equal :subclass_default, OptionSubclass.single_option
    assert_equal :single_option_default, OptionClass.single_option

    class_instance = OptionClass.new
    subclass_instance = OptionSubclass.new
    
    assert_equal :subclass_default, subclass_instance.single_option
    assert_equal :single_option_default, class_instance.single_option

    # Reset to defaults for next test
    OptionSubclass.single_option = nil
  end

  def test_boolean_option
    assert_equal nil, OptionClass.multi1
    
    instance = OptionClass.new
    
    instance.multi1 = false
    
    assert_equal false, instance.multi1
    assert_equal nil, OptionClass.multi1
    
    assert_equal nil, instance.multi2
  end
end
