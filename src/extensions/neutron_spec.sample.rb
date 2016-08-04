# copy to my_openstack_spec.rb

describe 'neutron API' do

  it 'can create a network' do
    response = openstack('network', 'create', 'test-network')
    provides(:test_network, response["id"])

    expect(response["status"]).to eq("ACTIVE")
    expect(response["name"]).to eq("test-network")
  end

  it 'can delete a network' do
    net_id = consumes(:test_network)
    openstack('network', 'delete', net_id)
  end

  context 'when a required resource is not available' do
    it 'does not run' do
      consumes(:missing_port)
    end
  end

end
