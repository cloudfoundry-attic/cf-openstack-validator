#!/usr/bin/env ruby

require 'json'
require 'net/http'
require_relative 'lib/parser'

unless ENV['INFLUX_IP'] && ENV['INFLUX_PORT'] && ENV['PIPELINE_NAME']
    puts "Set up environment first!"
    exit 1
end

filename = ARGV[0]
puts "Filename: #{filename}"
unless File.readable?(filename)
    puts "usage: #{$0} stats.log"
    exit 1
end

data = Parser.new(filename).to_influx(landscape: ENV['PIPELINE_NAME'])
puts data

http = Net::HTTP.new(ENV['INFLUX_IP'], ENV['INFLUX_PORT'])
request = Net::HTTP::Post.new('/write?db=validator')
request.body = data
response = http.request(request)

unless response.code == '204'
  puts 'Error sending data to InfluxDB'
  exit 1
end