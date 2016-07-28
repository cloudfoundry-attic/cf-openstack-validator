class CfValidator
  def self.resources
    @resources ||= ResourceTracker.new
  end

  def self.globals
    @globals ||= {}
  end

  def self.cli_resources
    @cli_resources ||= []
  end
end