require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class PigeonProcessorTest < Test::Unit::TestCase
  def test_empty_processor
    processor = Pigeon::Processor.new
    
    assert processor.empty?
  end
end
