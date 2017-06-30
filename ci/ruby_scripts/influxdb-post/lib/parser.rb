require 'json'

class Parser

  attr_accessor :data

  def initialize(file_path)
    @data = initialize_json(file_path)
  end

  def to_influx(args={})
    raise ArgumentError unless args.class == Hash

    additional_tags = args.map { |key, value| ",#{key.to_s}=#{value}"}.join('')

    data.map do |line|
      "cpi_duration,method=#{line['request']['method']}#{additional_tags} value=#{line['duration']} #{Parser.current_time_in_influx_format}"
    end.join("\n")
  end

  def self.current_time_in_influx_format
    Time.now.getutc.to_f.to_i * 1000000000
  end

  private

  def initialize_json(file_path)
    content = []
    File.read(file_path).each_line do |line|
      content << JSON.parse(line)
    end
    content
  end
end