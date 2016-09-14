module Validator
  class Resources

    def initialize
      @trackers = []
    end

    def new_tracker
      (@trackers << Api::ResourceTracker.new).last
    end

    def cleanup()
      @trackers.delete_if { |tracker| tracker.cleanup }

      @trackers.empty?
    end

    def count
      @trackers.inject(0) { |memo, tracker|
        memo + tracker.count
      }
    end

    def summary
      return 'All resources have been cleaned up' if count == 0

      resources_by_type = @trackers.map { |tracker|
        tracker.resources
      }.flatten.group_by { |resource| resource[:resource_type] }

      resource_type_summary = Api::ResourceTracker::RESOURCE_TYPES.map do |resource_type|
        resources = resources_by_type[resource_type]
        "  #{resource_type}:\n#{format_resources(resources)}" unless resources.nil?
      end.join

      "The following resources might not have been cleaned up:\n" + resource_type_summary
    end

    private
    def format_resources(resources)
      resources.map { |resource| "    #{resource[:resource_name]} / #{resource[:resource_id]} (#{resource[:test_description]})\n" }.join
    end

  end
end