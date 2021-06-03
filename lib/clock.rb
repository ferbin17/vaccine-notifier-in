require 'clockwork'
require 'active_support/time' # Allow numeric durations (eg: 1.minutes)
require 'yaml'
require 'logger'
require_relative 'vaccine-notifier'

module Clockwork
  handler do |job|
    puts "Running #{job}"
  end

  every((60).second, '60SecVaccineNotify', :if => lambda {|t| 15 <= t.hour || t.hour == 0 || t.hour == 1}){
    notify = VaccineNotifier.new.check_slots
    File.open(File.join(File.dirname(__FILE__), '../data/time.txt'), "w") { |f| f.write Time.now.to_i }
  }
  
  every((5).minute, '5MinVaccineNotify', :if => lambda {|t| 15 > t.hour && t.hour != 0 && t.hout != 1}){
    notify = VaccineNotifier.new.check_slots
    File.open(File.join(File.dirname(__FILE__), '../data/time.txt'), "w") { |f| f.write Time.now.to_i }
  }
end