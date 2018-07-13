RSpec.shared_context "resource tracker" do
  before(:all) do
    @resource_tracker = Validator::Api::ResourceTracker.create
  end

  after(:all) do
    puts "<<< resource_tracker#after_all"
    @resource_tracker.cleanup
  end
end
