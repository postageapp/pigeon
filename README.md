# Pigeon

This is a simple framework for building EventMachine engines that are
constantly running. These are commonly used for background processing jobs,
batch processing, or for providing specific network services.

Installation should be as simple as:

    gem install pigeon

Your first Pigeon engine can be defined by declaring a subclass:

    class MyEngine < Pigeon::Engine
      after_start do
        # Operations to be performed after start
      end
    end
    
Other handlers can be defined:

    after_initialize
    before_start
    after_start
    before_stop
    after_stop
    
A primary function of an engine might be to intermittently perform a task.
Several methods exist to facilitate this:

    class MyEngine < Pigeon::Engine
      after_start do
        periodically_trigger_task(10) do
          # Arbitrary block of code is executed every ten seconds but only
          # one instance of this block can be running at a time.
          do_stuff_every_ten_seconds
        end
      end
    end

Starting your application can be done with a wrapper script that is constructed somewhat like bin/launcher.example

An example would look like:

    #!/usr/bin/env ruby
    
    require 'rubygems'
    gem 'pigeon'

    # Adjust search path to include the ../lib directory
    $LOAD_PATH << File.expand_path(
      File.join(*%w[ .. lib ]), File.dirname(__FILE__)
    )

    # Use Pigeon::Launcher to launch your own engine by replacing
    # the parameter Pigeon::Engine with your specific subclass.
    Pigeon::Launcher.new(Pigeon::Engine).handle_args(ARGV)
    
## Components

There are several key components used by Pigeon to create an event-driven
engine.

### Pigeon::Dispatcher

The dispatcher functions as a thread pool for processing small, discrete
operations. These threads are created on demand and destroyed when no longer
in use. By limiting the number of threads a pool can contain it is possible
to schedule sequential operations, manage control over a single shared
resource, or to run through large lists of operations in parallel.

### Pigeon::SortedArray

This utility class provides a simple self-sorting array. This is used as a
priority queue within the Pigeon::Queue.

## Status

This engine is currently in development.

## Copyright

Copyright (c) 2009-2015 Scott Tadman, The Working Group
