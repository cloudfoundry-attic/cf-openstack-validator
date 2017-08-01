fdescribe 'Flavors' do
  let(:compute) do
    Validator::Api::FogOpenStack.compute
  end

  config = Validator::Api.configuration.extensions

  flavors = YAML.load_file(config['flavors']['expected_flavors'])

  let(:expected_flavor_properties) do
    flavors.map { |flavor| flavor.fetch('metadata', {}).keys }.flatten.uniq
  end

  it 'can get list of flavors' do
    flavor_list = compute.flavors
    expect(flavor_list).not_to be_nil, 'could not get list of flavors'
  end

  flavors.each do |flavor|
    describe "'#{flavor['name']}'" do
      let(:os_flavor) { compute.flavors.find { |f| f.name == flavor['name'] } }

      it 'exists' do
        fail_message = "Missing flavor '#{flavor['name']}'"
        expect(os_flavor).not_to be_nil, fail_message
      end

      it 'is configured' do
        Validator::Api.skip_test('flavor not present') unless os_flavor

        expected_attributes = ['ephemeral', 'name', 'ram', 'vcpus']
        given_attributes = flavor.keys.sort
        missing_attributes = (expected_attributes - given_attributes).join(',')
        expect(given_attributes).to eq(expected_attributes), "Following flavor attributes are missing: #{missing_attributes}"

        ram_size_gb = flavor['ram'] / 1024

        if os_flavor.ephemeral.nil? || os_flavor.ephemeral == 0
          disks_fail_message = "  disk >= #{3 + flavor['ephemeral'] + ram_size_gb} GiB (root (3 GiB) + ephemeral disk (#{flavor['ephemeral']} GiB) + ram (#{ram_size_gb} GiB))"
          disks_expectation_value = os_flavor.disk >= flavor['ephemeral'] + ram_size_gb + 3
        else
          disks_fail_message = "  disk >= 3 GiB \n" \
                               "  ephemeral disk >= #{flavor['ephemeral'] + ram_size_gb} GiB (ephemeral disk (#{flavor['ephemeral']} GiB) + ram (#{ram_size_gb} GiB))"
          disks_expectation_value = (os_flavor.ephemeral >= flavor['ephemeral'] + ram_size_gb) && (os_flavor.disk >= 3)
        end

        fail_message = "Expected: \n" +
                       flavor_vcpus_to_s(flavor, method(:get_value_from_hash)) +
                       flavor_ram_to_s(flavor, method(:get_value_from_hash)) +
                       disks_fail_message +
                       flavor_properties_to_s(flavor, method(:get_value_from_hash)) +
                       "\nGot (OpenStack): \n" +
                       flavor_to_s(os_flavor, method(:get_value_from_object))

        expect(
          os_flavor.vcpus == flavor['vcpus'] &&
          os_flavor.ram == flavor['ram'] &&
          disks_expectation_value &&
          check_flavor_properties(flavor.fetch('metadata', {}), os_flavor.metadata)
        ).to eq(true), fail_message
      end

      def get_value_from_hash(flavor, key)
        flavor.fetch(key, {})
      end

      def get_value_from_object(flavor, key)
        flavor.send(key)
      end

      def flavor_to_s(flavor, get_value)
        flavor_vcpus_to_s(flavor, get_value) +
          flavor_ram_to_s(flavor, get_value) +
          "  disk: #{get_value.call(flavor, 'disk')} GiB\n" \
          "  ephemeral: #{get_value.call(flavor, 'ephemeral')} GiB" +
          flavor_properties_to_s(flavor, get_value)
      end

      def flavor_vcpus_to_s(flavor, get_value)
        "  vcpus: #{get_value.call(flavor, 'vcpus')}\n"
      end

      def flavor_ram_to_s(flavor, get_value)
        "  ram: #{get_value.call(flavor, 'ram')} MiB\n"
      end

      def flavor_properties_to_s(flavor, get_value)
        result = ''
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
          result &&= properties[property] == os_properties[property]
        end
        result
      end
    end
  end
end
