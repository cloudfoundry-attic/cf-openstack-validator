class CfValidator
  def self.resources
    @resources ||= ResourceTracker.new
  end
end