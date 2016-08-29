# copy to ./dummy_extension_spec.rb to see it run
describe 'My extension' do
  it 'is true' do
    expect(true).to be(true)
  end

  context 'when requiring custom configuration' do
    it 'is available' do
      expect(extensions_config['custom-config-key']).to eq('custom-config-value')
    end
  end
end