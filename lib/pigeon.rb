module Pigeon
  # == Autoloads ============================================================
  
  autoload(:Backlog, 'pigeon/backlog')
  autoload(:Dispatcher, 'pigeon/dispatcher')
  autoload(:Engine, 'pigeon/engine')
  autoload(:Launcher, 'pigeon/launcher')
  autoload(:OptionAccessor, 'pigeon/option_accessor')
  autoload(:Pidfile, 'pigeon/pidfile')
  autoload(:Processor, 'pigeon/processor')
  autoload(:Queue, 'pigeon/queue')
  autoload(:Scheduler, 'pigeon/scheduler')
  autoload(:SortedArray, 'pigeon/sorted_array')
  autoload(:Support, 'pigeon/support')
  autoload(:Task, 'pigeon/task')

  # == Module Methods =======================================================

  def self.version
    @version ||= File.readlines(
      File.expand_path('../VERSION'), File.dirname(__FILE__)
    )[0].chomp
  end
end

# NOTE: This file needs to be directly loaded due to some kind of peculiar
# issue where requiring it later causes a run-time Interrupt exception.
require 'pigeon/logger'
