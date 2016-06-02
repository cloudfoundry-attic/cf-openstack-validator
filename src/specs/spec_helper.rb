RSpec.configure do |config|

  config.before(:suite) do
    $resources = {
        instances: [],
        images: [],
        volumes: [],
        snapshots: []
    }
  end

  config.after(:suite) do
    leaked_resources = $resources.inject(0) { |sum, entry| sum += entry[1].length }

    if leaked_resources > 0
      puts red "\nThe following resources might not have been cleaned up:\n"
      puts red $resources
                   .reject { |_, resource_ids| resource_ids.length == 0 }
                   .map { |resource_type, resource_ids| "  #{resource_type}: #{resource_ids.join(', ')}" }
                   .join("\n")
    end
  end
end

def red(string)
  "\e[31m#{string}\e[0m"
end