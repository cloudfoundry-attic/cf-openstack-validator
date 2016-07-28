require_relative 'spec_helper'


extension_dir = YAML.load_file(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])['extensions']['path']
specs = Dir.glob(File.join(extension_dir, "*_spec.rb"))

if specs.size > 0

  openstack_suite.describe 'Extensions', position: 3, order: :global do
    specs.each do |file|
      puts "Evaluating extension: #{file}"
      binding.eval(File.read(file), file)
    end

  end
end