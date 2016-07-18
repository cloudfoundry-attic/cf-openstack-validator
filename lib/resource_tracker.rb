class ResourceTracker

  RESOURCE_TYPES = [:servers, :volumes, :images, :snapshots]

  def initialize
    reset_resources
  end

  def count
    @resources.values.flatten.size
  end

  def track(type)
    unless RESOURCE_TYPES.include?(type)
      raise ArgumentError, "Invalid resource type '#{type}', use #{ResourceTracker::RESOURCE_TYPES.join(', ')}"
    end

    if block_given?
      resource_id = yield
      @resources[type] << resource_id
      resource_id
    end
  end

  def untrack_resource(resource_id)
    @resources.values.each do |resources_for_type|
      if resources_for_type.delete resource_id
        break
      end
    end
  end

  def summary
    if count > 0
      "The following resources might not have been cleaned up:\n" +
      @resources.reject { |_, resource_ids| resource_ids.length == 0 }
                .map { |resource_type, resource_ids| "  #{resource_type}: #{resource_ids.join(', ')}" }
                .join("\n")
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
          .select { |resource| tracked_resources.include?(resource.id) }
          .each { |resource|
          untrack_resource(resource.id) if resource.destroy }
      end
    end

    count == 0
  end

  private

  def untrack_resources_not_in_openstack(tracked_resources, resources_in_openstack)
    tracked_resources_not_in_openstack = tracked_resources.reject do |resource_id|
      resources_in_openstack.find do |resource_in_openstack|
        resource_in_openstack.id == resource_id
      end
    end

    tracked_resources_not_in_openstack.each { |resource_id| untrack_resource(resource_id) }
  end

  def reset_resources
    @resources = RESOURCE_TYPES.map do |type|
      [type, []]
    end.to_h
  end
end