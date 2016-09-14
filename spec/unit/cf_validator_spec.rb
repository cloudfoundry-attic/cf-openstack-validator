require_relative 'spec_helper'

describe 'Cf Validator' do

  it 'returns a resource tracker' do
    expect(CfValidator.resources.new_tracker).to be_a(Validator::Api::ResourceTracker)
  end

  it 'always returns the same resource tracker' do
    expect(CfValidator.resources).to be(CfValidator.resources)
  end
end

