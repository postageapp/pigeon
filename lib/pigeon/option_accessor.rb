module Pigeon::OptionAccessor
  # Given a list of names, this declares an option accessor which works like
  # a combination of cattr_accessor and attr_accessor, except that defaults
  # defined for a class will propagate down to the instances and subclasses,
  # but these defaults can be over-ridden in subclasses and instances
  # without interference. Optional hash at end of list can be used to set:
  #  * :default => Assigns a default value which is otherwise nil
  def option_accessor(*args, boolean: false, default: nil, on: [ :class, :instance ])
    option_reader(*args, boolean: boolean, default: default, on: on)
    option_writer(*args, boolean: boolean, on: on)
  end

  # Given a list of names, this declares an option reader which works like
  # a combination of cattr_reader and attr_reader, except that defaults
  # defined for a class will propagate down to the instances and subclasses,
  # but these defaults can be over-ridden in subclasses and instances
  # without interference. Optional hash at end of list can be used to set:
  #  * :default => Assigns a default value which is otherwise nil
  #  * :boolean => If true, creates an additional name? method and will
  #                convert all assigned values to a boolean true/false.
  def option_reader(*names, boolean: false, default: nil, on: [ :class, :instance ])
    names = [ names ].flatten.compact
    on = [ on ].flatten
    
    names.each do |name|
      iv = :"@#{name}"

      if (on.include?(:class))
        (class << self; self; end).class_eval do
          if (boolean)
            define_method(:"#{name}?") do
              iv_value = instance_variable_defined?(iv) ? instance_variable_get(iv) : nil

              !!(iv_value.nil? ? (self.superclass.respond_to?(name) ? self.superclass.send(name) : nil) : iv_value)
            end
          end

          define_method(name) do
            iv_value = instance_variable_defined?(iv) ? instance_variable_get(iv) : nil
            
            iv_value.nil? ? (self.superclass.respond_to?(name) ? self.superclass.send(name) : nil) : iv_value
          end
        end
      end
    
      if (on.include?(:instance))
        define_method(name) do
          iv_value = instance_variable_defined?(iv) ? instance_variable_get(iv) : nil

          iv_value.nil? ? self.class.send(name) : iv_value
        end

        if (boolean)
          define_method(:"#{name}?") do
            iv_value = instance_variable_defined?(iv) ? instance_variable_get(iv) : nil

            !!(iv_value.nil? ? self.class.send(name) : iv_value)
          end
        end
      end
      
      instance_variable_set(iv, default)
    end
  end

  # Given a list of names, this declares an option writer which works like
  # a combination of cattr_writer and attr_writer, except that defaults
  # defined for a class will propagate down to the instances and subclasses,
  # but these defaults can be over-ridden in subclasses and instances
  # without interference.
  def option_writer(*names, boolean: false, on: [ :class, :instance ])
    names = [ names ].flatten.compact
    on = [ on ].flatten
    
    names.each do |name|
      iv = :"@#{name}"

      if (on.include?(:class))
        (class << self; self; end).class_eval do
          if (boolean)
            define_method(:"#{name}=") do |value|
              instance_variable_set(iv, value.nil? ? nil : !!value)
            end
          else
            define_method(:"#{name}=") do |value|
              instance_variable_set(iv, value)
            end
          end
        end
      end
    
      if (on.include?(:instance))
        if (boolean)
          define_method(:"#{name}=") do |value|
            instance_variable_set(iv, value.nil? ? nil : !!value)
          end
        else
          define_method(:"#{name}=") do |value|
            instance_variable_set(iv, value)
          end
        end
      end
    end
  end
end
