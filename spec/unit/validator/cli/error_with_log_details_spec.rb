require_relative '../../spec_helper'

module Validator::Cli
  describe ErrorWithLogDetails do

    subject { ErrorWithLogDetails.new(log_path) }
    describe '.new' do
      it 'raises without a log path' do
        expect{ ErrorWithLogDetails.new }.to raise_error(ArgumentError)
      end
    end

    describe '#log_path' do
      let(:log_path) { File.join('/tmp') }
      it 'returns the log path' do
        expect(subject.log_path).to eq('/tmp')
      end
    end
  end
end