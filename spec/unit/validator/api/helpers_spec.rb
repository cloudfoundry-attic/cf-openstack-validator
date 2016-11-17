require_relative '../../spec_helper'

include Validator::Api::Helpers

describe Validator::Api::Helpers do
  describe '.red' do
    it 'adds escape sequences to color a string red' do
      expect(red("some-string")).to eq("\e[31msome-string\e[0m")
    end
  end
end