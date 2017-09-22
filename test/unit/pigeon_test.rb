require_relative '../helper'

class TestPigeon < Minitest::Test
  def test_load_module
    assert Pigeon
  end
end
