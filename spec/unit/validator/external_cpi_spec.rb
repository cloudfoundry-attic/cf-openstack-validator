require_relative '../spec_helper'

describe Validator::ExternalCpi do

  let(:tmpdir) { Dir.mktmpdir }
  let(:log_file) { File.join(tmpdir, 'testsuite.log') }
  let(:cpi_task_log_path) { File.join(tmpdir, 'task.log') }
  let(:logger) { Logger.new(log_file) }
  let(:cpi_path) { '/path/to/cpi' }
  let(:stats_log_path) { File.join(tmpdir, 'stats.log') }
  let(:response) {
    {
      'result' => '',
      'error' => {
        'type' => 'Bosh::Clouds::NotSupported',
        'message' => 'The given method is not supported',
        'ok_to_retry' => false
      },
      'log' => ''
    }.to_json
  }

  subject {
    Validator::ExternalCpi.new(cpi_path, logger, cpi_task_log_path, stats_log_path)
  }

  before(:each) {
    FileUtils.touch(log_file)
    FileUtils.touch(cpi_task_log_path)
    allow(Open3).to receive(:capture3).and_return([response, nil, nil])
  }

  after(:each) {
    FileUtils.rm_rf(tmpdir)
  }

  context 'when the cpi is not executable' do
    it 'raises' do
      expect{
        subject.current_vm_id
      }.to raise_error(Validator::ExternalCpi::NonExecutable)
    end
  end

  context 'when the cpi responce is not a hash' do
    let(:response) { {} }
    before do
      allow(File).to receive(:executable?).with(cpi_path).and_return(cpi_path)
    end

    it 'raises' do
      expect{
        subject.current_vm_id
      }.to raise_error(Validator::ExternalCpi::InvalidResponse)
    end
  end

  context 'when the cpi returns an error' do
    before do
      allow(File).to receive(:executable?).with(cpi_path).and_return(cpi_path)
    end

    it 'raises' do
      expect{
        subject.current_vm_id
      }.to raise_error(Validator::ExternalCpi::CpiError, "CPI error 'Bosh::Clouds::NotSupported' with message 'The given method is not supported' in 'current_vm_id' CPI method")
    end
  end

  context 'when the cpi does not return an error' do
    let(:response) {
      {
          'result' => '',
          'error' => nil,
          'log' => ''
      }.to_json
    }

    before do
      allow(File).to receive(:executable?).with(cpi_path).and_return(cpi_path)
    end

    it 'sets a director_uuid in the context' do
      subject.current_vm_id

      expect(Open3).to have_received(:capture3).with(anything, anything, contains_director_uuid('validator'))
    end

    context 'logging stats' do
      let(:start_time) { Time.new(2016,12,12,1,0,0).utc }
      let(:end_time) { Time.new(2016,12,12,1,1,30).utc }
      let(:duration) { (end_time - start_time) }
      let(:response) {
        {
            'result' => '',
            'error' => nil,
            'log' => ''
        }.to_json
      }

      before(:each) do
        allow(subject).to receive(:generate_request_id).and_return('777777')
        allow(Benchmark).to receive(:measure) do |&block|
          block.call
          instance_double(Benchmark::Tms, real: duration)
        end
      end

      it 'logs the data to the given path' do
        subject.current_vm_id('1', '2', '3', '4')

        expect(JSON.load(File.read(stats_log_path))).to eq({
            'request' => {
                'method' => 'current_vm_id',
                'arguments' => ['1', '2', '3', '4'],
                'context' => {
                    'director_uuid' => 'validator',
                    'request_id' => '777777'
                }
            },
            'duration' => 90
        })
      end

      it 'appends additional calls to the file' do
        subject.current_vm_id('1', '2', '3', '4')
        subject.current_vm_id('6', '7', '8', '9')

        calls = File.read(stats_log_path).split("\n")

        expect(JSON.load(calls[0])).to eq({
            'request' => {
                'method' => 'current_vm_id',
                'arguments' => ['1', '2', '3', '4'],
                'context' => {
                    'director_uuid' => 'validator',
                    'request_id' => '777777'
                }
            },
            'duration' => 90
        })

        expect(JSON.load(calls[1])).to eq({
            'request' => {
                'method' => 'current_vm_id',
                'arguments' => ['6', '7', '8', '9'],
                'context' => {
                    'director_uuid' => 'validator',
                    'request_id' => '777777'
                }
            },
            'duration' => 90
        })
      end
    end
  end
end

RSpec::Matchers.define :contains_director_uuid do |value|
  match do |actual|
    request = JSON.load(actual[:stdin_data])
    request['context']['director_uuid'] == value
  end
end
