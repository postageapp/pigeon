require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class TestPigeon < Test::Unit::TestCase
  def test_load_module
    assert Pigeon
  end
end
