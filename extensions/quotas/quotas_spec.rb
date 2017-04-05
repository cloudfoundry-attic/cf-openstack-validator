describe 'Quotas' do

  config = Validator::Api.configuration.extensions
  quotas = YAML.load_file( config['quotas']['expected_quotas'])

  let(:project_id) { config['quotas']['project_id'] }
  let(:compute_quota) do
    Validator::Api::FogOpenStack.compute.get_quota(project_id).body['quota_set']
  end
  let(:volume_quota) do
    Validator::Api::FogOpenStack.volume.get_quota(project_id).body['quota_set']
  end
  let(:network_quota) do
    Validator::Api::FogOpenStack.network.get_quota(project_id).body['quota']
  end

  quotas['compute'].each do |key, value|
    it key do
      os_quota = compute_quota[key]
      expect(os_quota == -1 || os_quota >= value).to eq(true), "Quota for '#{key}' should be greater than '#{value}', but is '#{os_quota}'"
    end
  end

  quotas['volume'].each do |key, value|
    it key do
      os_quota = volume_quota[key]
      expect(os_quota == -1 || os_quota >= value).to eq(true), "Quota for '#{key}' should be greater than '#{value}', but is '#{os_quota}'"
    end
  end

  quotas['network'].each do |key, value|
    it key do
      os_quota = network_quota[key]
      expect(os_quota == -1 || os_quota >= value).to eq(true), "Quota for '#{key}' should be greater than '#{value}', but is '#{os_quota}'"
    end
  end

end