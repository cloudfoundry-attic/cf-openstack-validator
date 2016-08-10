class ResourceTracker

  RESOURCE_TYPES = [:servers, :volumes, :images, :snapshots]

  def initialize
    reset_resources
  end

  def count
    @resources.values.flatten.size
  end

  def track(compute, type, test_description)
    unless RESOURCE_TYPES.include?(type)
      raise ArgumentError, "Invalid resource type '#{type}', use #{ResourceTracker::RESOURCE_TYPES.join(', ')}"
    end

    if block_given?
      resource_id = yield
      resource_name = compute.send(type).get(resource_id).name
      @resources[type] << { resource_name: resource_name, resource_id: resource_id, test_description: test_description }
      resource_id
    end
  end

  def untrack_resource(resource_id)
    @resources.values.each do |resources_for_type|
      resource = resources_for_type.find {|resource| resource[:resource_id] == resource_id}
      if resource
        resources_for_type.delete(resource)
        break
      end
    end
  end

  def summary
    if count > 0
      "The following resources might not have been cleaned up:\n" +
      @resources.reject { |_, resources| resources.length == 0 }
                .map { |resource_type, resources| "  #{resource_type}:\n#{format_resources(resources)}" }
                .join
    else
      'All resources have been cleaned up'
    end
  end

  def untrack(compute, cleanup:)
    RESOURCE_TYPES.each do |type|
      tracked_resources = @resources[type]
      resources_in_openstack = compute.send(type)

      untrack_resources_not_in_openstack(tracked_resources, resources_in_openstack)

      if cleanup
        resources_in_openstack
          .select { |resource| tracked_resources.find{ |tracked_resource| tracked_resource[:resource_id] == resource.id }}
          .each { |resource|
          untrack_resource(resource.id) if resource.destroy }
      end
    end

    count == 0
  end

  private

  def format_resources(resources)
    resources.map{ |resource| "    #{resource[:resource_name]} / #{resource[:resource_id]} (#{resource[:test_description]})\n"}.join
  end

  def untrack_resources_not_in_openstack(tracked_resources, resources_in_openstack)
    tracked_resources_not_in_openstack = tracked_resources.reject do |resource|
      resources_in_openstack.find do |resource_in_openstack|
        resource_in_openstack.id == resource[:resource_id]
      end
    end

    tracked_resources_not_in_openstack.each { |resource| untrack_resource(resource[:resource_id]) }
  end

  def reset_resources
    @resources = RESOURCE_TYPES.map do |type|
      [type, []]
    end.to_h
  end
end