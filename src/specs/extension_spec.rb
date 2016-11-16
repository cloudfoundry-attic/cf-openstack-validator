require_relative 'spec_helper'

specs = Validator::Extensions.all
if specs.size > 0
  openstack_suite.describe 'Extensions', position: 3, order: :global do
    Validator::Extensions.eval(specs, binding)
  end
end