require_relative 'spec_helper'

specs = Extensions.all
if specs.size > 0
  openstack_suite.describe 'Extensions', position: 3, order: :global do
    Extensions.eval(specs, binding)
  end
end