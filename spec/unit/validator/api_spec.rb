require_relative '../spec_helper'

describe 'API' do
  describe '.skip_test' do
    it 'should make test pending' do |test|
      expect(test.example_group_instance).to receive(:skip).with('some message')

      Validator::Api.skip_test('some message')
      end
  end
end