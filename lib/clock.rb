require 'clockwork'
require 'active_support/time' # Allow numeric durations (eg: 1.minutes)
require 'yaml'
require 'logger'
require_relative 'vaccine-notifier'

module Clockwork
  handler do |job|
    puts "Running #{job}"
  end

  every((60).second, 'VaccineNotify'){
    receivers = YAML.load_file(File.join(File.dirname(__FILE__), '../data/notify.yml'))["receivers"]
    receivers.each do |receiver|
      receiver_data = receiver.split(", ")
      notify = VaccineNotifier.new(receiver_data[0], receiver_data[1], receiver_data[2], receiver_data[3], receiver_data[4], receiver_data[5])
      notify.perform
    end
    File.open(File.join(File.dirname(__FILE__), '../data/time.txt'), "w+") { |f| f.write Time.now.to_i }
  }
end

