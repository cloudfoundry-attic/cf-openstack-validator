#!/usr/bin/env ruby
#

require 'json'
require 'net/http'

unless ENV['INFLUX_URL'] && ENV['INFLUX_USER'] && ENV['INFLUX_PASSWORD'] 
    puts "set up environment first!"
    exit 1
end

filename = ARGS[1]
unless File.readable?(filename)
    puts "usage: #{$0} stats.log"
    exit 1
end

data = []
File.read(filename).each_line do |line|
    line.chomp!

    data << JSON.parse(line).map { |key, value| "#{key}=#{value}" }.join(' ')

end

puts data.join("\n")
