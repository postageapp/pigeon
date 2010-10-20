module Pigeon
  # == Autoloads ============================================================
  
  autoload(:Engine, 'pigeon/engine')
  autoload(:Launcher, 'pigeon/launcher')
  autoload(:OptionAccessor, 'pigeon/option_accessor')
  autoload(:Pidfile, 'pigeon/pidfile')
  autoload(:Queue, 'pigeon/queue')
  autoload(:Support, 'pigeon/support')
end

require 'pigeon/logger'