#!/usr/bin/env ruby

require 'json'
require 'net/http'
require_relative 'lib/parser'

unless ENV['INFLUXDB_IP'] && ENV['INFLUXDB_PORT'] && ENV['PIPELINE_NAME'] && ENV['INFLUXDB_USER'] && ENV['INFLUXDB_PASSWORD']
    puts 'Set up environment first. INFLUXDB_IP, INFLUXDB_PORT, INFLUXDB_USER, INFLUXDB_PASSWORD and PIPELINE_NAME need to be set.'
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

http = Net::HTTP.new(ENV['INFLUXDB_IP'], ENV['INFLUXDB_PORT'])
request = Net::HTTP::Post.new('/write?db=validator')
request.basic_auth(ENV['INFLUXDB_USER'], ENV['INFLUXDB_PASSWORD'])
request.body = data
response = http.request(request)

unless response.code == '204'
  puts 'Error sending data to InfluxDB'
  exit 1
end