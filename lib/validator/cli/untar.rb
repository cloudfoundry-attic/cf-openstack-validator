module Validator::Cli
  class Untar
    def self.extract_archive(archive, destination)
      FileUtils.mkdir_p(destination)

      _, stderr, status = Open3.capture3("tar -xzf #{archive} -C #{destination}")
      if status.exitstatus != 0
        raise StandardError.new("Error extracting '#{archive}' to '#{destination}': #{stderr}")
      end
    end
  end
end