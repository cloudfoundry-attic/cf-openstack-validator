module Validator
  class StatsLog
    def initialize(path)
      @path = path
    end

    def append(request, measure)
      File.open(@path, 'a') do |f|
        f.puts(JSON.dump({ 'request' => request, 'duration' => measure.real }))
      end
    end
  end
end
