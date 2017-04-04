describe 'Flavors' do

  let(:compute) {
    Validator::Api::FogOpenStack.compute
  }
 
  config = Validator::Api.configuration.extensions
  
  flavors = YAML.load_file( config['flavors']['expected_flavors'])

  let(:expected_flavor_properties) do
    flavors.map {|flavor| flavor.fetch('metadata', {}).keys}.flatten.uniq
  end

  it "can get flavors" do
    flavor_list = compute.flavors
    expect(flavor_list).not_to be_nil, "could not get list of flavors"
  end

  flavors.each do |flavor|
    describe "check flavor '#{flavor['name']}'" do
      let(:os_flavor) { compute.flavors.find { |f| f.name == flavor['name'] } }
      it "exists" do
        fail_message = "Missing flavor '#{flavor['name']}'. \n" +
                       "Hint: Create flavor '#{flavor['name']}' with \n"+
                       flavor_to_s(flavor, method(:get_value_from_hash))
        expect(os_flavor).not_to be_nil, fail_message
      end
      it "has expected configuration" do
        Validator::Api::skip_test("flavor not present") unless os_flavor
        fail_message = "Unexpected flavor configuration for '#{flavor['name']}' \n" +
                       "Found:\n" +
                       flavor_to_s(os_flavor, method(:get_value_from_object)) +
                       "\nExpected:\n" +
                       flavor_to_s(flavor, method(:get_value_from_hash))
        
        expect(os_flavor.vcpus == flavor['vcpus'] &&
               os_flavor.ram == flavor['ram'] &&
               os_flavor.disk == flavor['disk'] &&
               check_flavor_properties(flavor.fetch('metadata',{}), os_flavor.metadata)
              ).to eq(true), fail_message
      end
      
      def get_value_from_hash(flavor, key)
        flavor.fetch(key, {})
      end

      def get_value_from_object(flavor, key)
        flavor.send(key)
      end

      def flavor_to_s(flavor, get_value)
        result = "  vcpus: #{get_value.call(flavor, 'vcpus')}\n" + 
                 "  ram: #{get_value.call(flavor, 'ram')} Mb\n" +
                 "  disk: #{get_value.call(flavor, 'disk')} Gb"
        if expected_flavor_properties != []
          result += "\n  Properties:"
            expected_flavor_properties.each do |property|
              result += "\n    #{property}: #{get_value.call(flavor, 'metadata')[property] || 'not set'}"
            end
        end
        result
      end

      def check_flavor_properties(properties, os_properties)
        result = true
         expected_flavor_properties.each do |property|
           result = result && properties[property] == os_properties[property]
         end
         result
      end
      
    end
  end 
end
