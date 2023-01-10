# frozen_string_literal: true
require 'test/unit'

class TestTimeStrptime < Test::Unit::TestCase
  def time_to_h(t)
    h = {}
    [:year,:mon,:mday,:hour,:min,:sec,:zone,:gmt_offset,:wday].each do |key|
      h[key] = t.send(key)
    end
    h
  end

  def test_strptime
    assert_equal(Time.new(2002,3,14,11,22,33, 0),
		 Time.strptime('2002-03-14T11:22:33Z', '%Y-%m-%dT%H:%M:%S%z'))
    assert_equal(Time.new(2002,3,14,11,22,33, 9*3600),
		 Time.strptime('2002-03-14T11:22:33+09:00', '%Y-%m-%dT%H:%M:%S%z'))
    assert_equal(Time.new(2002,3,14,11,22,33, -9*3600),
		 Time.strptime('2002-03-14T11:22:33-09:00', '%FT%T%z'))
    assert_equal(Time.new(2002,3,14,11,22,33, -9*3600) + 123456789.to_r/1000000000,
		 Time.strptime('2002-03-14T11:22:33.123456789-09:00', '%FT%T.%N%z'))
  end

  def test_strptime2
    [
     # iso8601
     [['2001-02-03', '%Y-%m-%d'], [2001,2,3,nil,nil,nil,nil,nil,nil], __LINE__],
     [['2001-02-03T23:59:60', '%Y-%m-%dT%H:%M:%S'], [2001,2,3,23,59,60,nil,nil,nil], __LINE__],
     [['2001-02-03T23:59:60+09:00', '%Y-%m-%dT%H:%M:%S%Z'], [2001,2,3,23,59,60,'+09:00',9*3600,nil], __LINE__],
     [['-2001-02-03T23:59:60+09:00', '%Y-%m-%dT%H:%M:%S%Z'], [-2001,2,3,23,59,60,'+09:00',9*3600,nil], __LINE__],
     [['+012345-02-03T23:59:60+09:00', '%Y-%m-%dT%H:%M:%S%Z'], [12345,2,3,23,59,60,'+09:00',9*3600,nil], __LINE__],
     [['-012345-02-03T23:59:60+09:00', '%Y-%m-%dT%H:%M:%S%Z'], [-12345,2,3,23,59,60,'+09:00',9*3600,nil], __LINE__],

     # ctime(3), asctime(3)
     [['Thu Jul 29 14:47:19 1999', '%c'], [1999,7,29,14,47,19,nil,nil,4], __LINE__],
     [['Thu Jul 29 14:47:19 -1999', '%c'], [-1999,7,29,14,47,19,nil,nil,4], __LINE__],

     # date(1)
     [['Thu Jul 29 16:39:41 EST 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'EST',-5*3600,4], __LINE__],
     [['Thu Jul 29 16:39:41 MET DST 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'MET DST',2*3600,4], __LINE__],
     [['Thu Jul 29 16:39:41 AMT 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'AMT',nil,4], __LINE__],
     [['Thu Jul 29 16:39:41 AMT -1999', '%a %b %d %H:%M:%S %Z %Y'], [-1999,7,29,16,39,41,'AMT',nil,4], __LINE__],
     [['Thu Jul 29 16:39:41 GMT+09 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'GMT+09',9*3600,4], __LINE__],
     [['Thu Jul 29 16:39:41 GMT+0908 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'GMT+0908',9*3600+8*60,4], __LINE__],
     [['Thu Jul 29 16:39:41 GMT+090807 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'GMT+090807',9*3600+8*60+7,4], __LINE__],
     [['Thu Jul 29 16:39:41 GMT-09 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'GMT-09',-9*3600,4], __LINE__],
     [['Thu Jul 29 16:39:41 GMT-09:08 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'GMT-09:08',-9*3600-8*60,4], __LINE__],
     [['Thu Jul 29 16:39:41 GMT-09:08:07 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'GMT-09:08:07',-9*3600-8*60-7,4], __LINE__],
     [['Thu Jul 29 16:39:41 GMT-3.5 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'GMT-3.5',-3*3600-30*60,4], __LINE__],
     [['Thu Jul 29 16:39:41 GMT-3,5 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'GMT-3,5',-3*3600-30*60,4], __LINE__],
     [['Thu Jul 29 16:39:41 Mountain Daylight Time 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'Mountain Daylight Time',-6*3600,4], __LINE__],
     [['Thu Jul 29 16:39:41 E. Australia Standard Time 1999', '%a %b %d %H:%M:%S %Z %Y'], [1999,7,29,16,39,41,'E. Australia Standard Time',10*3600,4], __LINE__],

     # rfc822
     [['Thu, 29 Jul 1999 09:54:21 UT', '%a, %d %b %Y %H:%M:%S %Z'], [1999,7,29,9,54,21,'UT',0,4], __LINE__],
     [['Thu, 29 Jul 1999 09:54:21 GMT', '%a, %d %b %Y %H:%M:%S %Z'], [1999,7,29,9,54,21,'GMT',0,4], __LINE__],
     [['Thu, 29 Jul 1999 09:54:21 PDT', '%a, %d %b %Y %H:%M:%S %Z'], [1999,7,29,9,54,21,'PDT',-7*3600,4], __LINE__],
     [['Thu, 29 Jul 1999 09:54:21 z', '%a, %d %b %Y %H:%M:%S %Z'], [1999,7,29,9,54,21,'z',0,4], __LINE__],
     [['Thu, 29 Jul 1999 09:54:21 +0900', '%a, %d %b %Y %H:%M:%S %Z'], [1999,7,29,9,54,21,'+0900',9*3600,4], __LINE__],
     [['Thu, 29 Jul 1999 09:54:21 +0430', '%a, %d %b %Y %H:%M:%S %Z'], [1999,7,29,9,54,21,'+0430',4*3600+30*60,4], __LINE__],
     [['Thu, 29 Jul 1999 09:54:21 -0430', '%a, %d %b %Y %H:%M:%S %Z'], [1999,7,29,9,54,21,'-0430',-4*3600-30*60,4], __LINE__],
     [['Thu, 29 Jul -1999 09:54:21 -0430', '%a, %d %b %Y %H:%M:%S %Z'], [-1999,7,29,9,54,21,'-0430',-4*3600-30*60,4], __LINE__],

     # etc
     [['06-DEC-99', '%d-%b-%y'], [1999,12,6,nil,nil,nil,nil,nil,nil], __LINE__],
     [['sUnDay oCtoBer 31 01', '%A %B %d %y'], [2001,10,31,nil,nil,nil,nil,nil,0], __LINE__],
     [["October\t\n\v\f\r 15,\t\n\v\f\r99", '%B %d, %y'], [1999,10,15,nil,nil,nil,nil,nil,nil], __LINE__],
     [["October\t\n\v\f\r 15,\t\n\v\f\r99", '%B%t%d,%n%y'], [1999,10,15,nil,nil,nil,nil,nil,nil], __LINE__],

     [['09:02:11 AM', '%I:%M:%S %p'], [nil,nil,nil,9,2,11,nil,nil,nil], __LINE__],
     [['09:02:11 A.M.', '%I:%M:%S %p'], [nil,nil,nil,9,2,11,nil,nil,nil], __LINE__],
     [['09:02:11 PM', '%I:%M:%S %p'], [nil,nil,nil,21,2,11,nil,nil,nil], __LINE__],
     [['09:02:11 P.M.', '%I:%M:%S %p'], [nil,nil,nil,21,2,11,nil,nil,nil], __LINE__],

     [['12:33:44 AM', '%r'], [nil,nil,nil,0,33,44,nil,nil,nil], __LINE__],
     [['01:33:44 AM', '%r'], [nil,nil,nil,1,33,44,nil,nil,nil], __LINE__],
     [['11:33:44 AM', '%r'], [nil,nil,nil,11,33,44,nil,nil,nil], __LINE__],
     [['12:33:44 PM', '%r'], [nil,nil,nil,12,33,44,nil,nil,nil], __LINE__],
     [['01:33:44 PM', '%r'], [nil,nil,nil,13,33,44,nil,nil,nil], __LINE__],
     [['11:33:44 PM', '%r'], [nil,nil,nil,23,33,44,nil,nil,nil], __LINE__],

     [['11:33:44 PM AMT', '%I:%M:%S %p %Z'], [nil,nil,nil,23,33,44,'AMT',nil,nil], __LINE__],
     [['11:33:44 P.M. AMT', '%I:%M:%S %p %Z'], [nil,nil,nil,23,33,44,'AMT',nil,nil], __LINE__],

     [['fri1feb034pm+5', '%a%d%b%y%H%p%Z'], [2003,2,1,16,nil,nil,'+5',5*3600,5]],
     [['E.  Australia Standard Time', '%Z'], [nil,nil,nil,nil,nil,nil,'E.  Australia Standard Time',10*3600,nil], __LINE__],

     # out of range
     [['+0.9999999999999999999999', '%Z'], [nil,nil,nil,nil,nil,nil,'+0.9999999999999999999999',+1*3600,nil], __LINE__],
     [['+9999999999999999999999.0', '%Z'], [nil,nil,nil,nil,nil,nil,'+9999999999999999999999.0',nil,nil], __LINE__],
    ].each do |x, y|
      h = time_to_h(Time.strptime(*x))
      a = h.values_at(:year,:mon,:mday,:hour,:min,:sec,:zone,:gmt_offset,:wday)
      if y[1] == -1
	a[1] = -1
	a[2] = h[:yday]
      end
      p(y, a, [x, y, a].inspect)
    end
  end
end
