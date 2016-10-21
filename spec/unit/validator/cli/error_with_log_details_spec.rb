require_relative '../../spec_helper'

module Validator::Cli
  describe ErrorWithLogDetails do

    subject { ErrorWithLogDetails.new(log_path, error_message) }
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

    describe '#message' do
      let(:log_path) { 'a-log-path'}
      let(:error_message) { 'an error message' }

      it 'prints error message and log path' do
        expected_output = <<EOT
Error: an error message

More details can be found in a-log-path
EOT
        expect(subject.message).to eq(expected_output)
      end
    end
  end
end