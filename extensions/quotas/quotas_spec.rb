describe 'Quotas' do

  config = Validator::Api.configuration.extensions
  loaded_quotas = YAML.load_file(config['quotas']['expected_quotas'])
  quotas = loaded_quotas ? loaded_quotas : {}

  let(:project_id) { config['quotas']['project_id'] }

  unless loaded_quotas
    it 'executes quota tests' do
      skip("No quota expectation defined in #{config['quotas']['expected_quotas']}")
    end
  end

  context 'compute' do
    let(:compute_quota) do
      Validator::Api::FogOpenStack.compute.get_quota(project_id).body['quota_set']
    end
    compute_quotas = quotas['compute'] ? quotas['compute'] : []

    compute_quotas.each do |key, value|
      it key do
        os_quota = compute_quota[key]
        expect(os_quota == -1 || os_quota >= value).to eq(true), "Quota for '#{key}' should be greater than '#{value}', but is '#{os_quota}'"
      end
    end
  end

  context 'volume' do
    let(:volume_quota) do
      Validator::Api::FogOpenStack.volume.get_quota(project_id).body['quota_set']
    end
    volume_quotas = quotas['volume'] ? quotas['volume'] : []

    volume_quotas.each do |key, value|
      it key do
        os_quota = volume_quota[key]
        expect(os_quota == -1 || os_quota >= value).to eq(true), "Quota for '#{key}' should be greater than '#{value}', but is '#{os_quota}'"
      end
    end
  end

  context 'network' do
    let(:network_quota) do
      Validator::Api::FogOpenStack.network.get_quota(project_id).body['quota']
    end
    network_quotas = quotas['network'] ? quotas['network'] : []

    network_quotas.each do |key, value|
      it key do
        os_quota = network_quota[key]
        expect(os_quota == -1 || os_quota >= value).to eq(true), "Quota for '#{key}' should be greater than '#{value}', but is '#{os_quota}'"
      end
    end
  end
end