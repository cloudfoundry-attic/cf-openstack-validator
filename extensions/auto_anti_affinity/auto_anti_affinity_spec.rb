describe 'Auto-anti-affinity' do

  before(:all) do
    @resource_tracker = Validator::Api::ResourceTracker.create
  end

  let(:project_id) { Validator::Api.configuration.extensions['auto_anti_affinity']['project_id'] }

  let(:compute_quota) do
    Validator::Api::FogOpenStack.compute.get_quota(project_id).body['quota_set']
  end

  it 'quota is unlimited for server groups' do
    quota_server_groups = compute_quota['server_groups']
    expect(quota_server_groups).to eq(-1), "Quota for server_groups should be '-1' but is '#{quota_server_groups}'"
  end

  it 'quota is unlimited for server group members' do
    quota_members = compute_quota['server_group_members']
    expect(quota_members).to eq(-1), "Quota for server_groups should be '-1' but is '#{quota_members}'"
  end

  it "can create a server group with 'soft-anti-affinity'", cpi_api: true do
    begin
      server_group = @resource_tracker.produce(:server_groups) {
        Validator::Api::FogOpenStack.compute.server_groups.create('validator-test', 'soft-anti-affinity').id
      }
    rescue Excon::Errors::BadRequest => error
      if error.message.match(/Invalid input.*'soft-anti-affinity' is not one of/)
        message = "The server group policy 'soft-anti-affinity' is not supported by your OpenStack. The feature is available with Nova Microversion 2.15 (OpenStack Mitaka and higher)."
        fail(message)
      else
        raise error
      end
    end

    expect(server_group).to be
  end
end