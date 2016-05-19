#!/usr/bin/env ruby
$: << File.dirname(__FILE__)+'/lib'
require 'benchmark/ips'
require 'fast_blank'

class String
  # active support implementation
  def slow_blank?
    /\A[[:space:]]*\z/ === self
  end

  def new_slow_blank?
    empty? || !(/[[:^space:]]/ === self)
  end

  def n24_slow_blank?
    empty? || !(/[[:^space:]]/.match? self)
  end
end

test_strings = [
  "",
  "\r\n\r\n  ",
  "this is a test",
  "   this is a longer test",
  "   this is a longer test
      this is a longer test
      this is a longer test
      this is a longer test
      this is a longer test",
  "                           
                           
                           
                           
                                 "
]

test_strings.each do |s|
  raise "failed on #{s.inspect}" if s.blank? != s.slow_blank?
  raise "failed on #{s.inspect}" if s.blank? != s.new_slow_blank?
  raise "failed on #{s.inspect}" if s.blank? != s.n24_slow_blank?
  raise "failed on #{s.inspect}" if s.blank? != s.sttni_blank?
  raise "failed on #{s.inspect}" if s.blank? != s.opt_sttni_blank?
end

test_strings.each do |s|
  puts "\n================== Test String Length: #{s.length} =================="
  Benchmark.ips do |x|
    x.report("Fast Blank") do |times|
      i = 0
      while i < times
        s.blank?
        i += 1
      end
    end

    x.report("Fast ActiveSupport") do |times|
      i = 0
      while i < times
        s.blank_as?
        i += 1
      end
    end

    x.report("Slow Blank") do |times|
      i = 0
      while i < times
        s.slow_blank?
        i += 1
      end
    end

    x.report("New Slow Blank") do |times|
      i = 0
      while i < times
        s.new_slow_blank?
        i += 1
      end
    end

    x.report("New 2.4 Slow Blank") do |times|
      i = 0
      while i < times
        s.n24_slow_blank?
        i += 1
      end
    end

    x.report("STTNI Blank") do |times|
      i = 0
      while i < times
        s.sttni_blank?
        i += 1
      end
    end

    x.report("OPT STTNI Blank") do |times|
      i = 0
      while i < times
        s.opt_sttni_blank?
        i += 1
      end
    end

    x.compare!
  end
end
