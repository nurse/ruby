# frozen_string_literal: false
require 'test/unit'
require '-test-/integer'

class TestInteger < Test::Unit::TestCase
  FIXNUM_MIN = RbConfig::Limits['FIXNUM_MIN']
  FIXNUM_MAX = RbConfig::Limits['FIXNUM_MAX']

  def test_fixnum_range
    assert_bignum(FIXNUM_MIN-1)
    assert_fixnum(FIXNUM_MIN)
    assert_fixnum(FIXNUM_MAX)
    assert_bignum(FIXNUM_MAX+1)
  end

  def test_fixable
    assert_nil(Bug::Integer.test_bool)
    assert_nil(Bug::Integer.test_float)
    assert_nil(Bug::Integer.test_double)
    assert_nil(Bug::Integer.test_long_double)
    assert_nil(Bug::Integer.test_long)
    assert_nil(Bug::Integer.test_ulong)
    assert_nil(Bug::Integer.test_int128)
    assert_nil(Bug::Integer.test_uint128)
  end
end
