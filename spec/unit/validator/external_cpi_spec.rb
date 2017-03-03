require_relative '../spec_helper'

describe Validator::ExternalCpi do

  let(:tmpdir) { Dir.mktmpdir }
  let(:log_file) { File.join(tmpdir, 'testsuite.log') }
  let(:cpi_task_log_path) { File.join(tmpdir, 'task.log') }
  let(:logger) { Logger.new(log_file) }
  let(:cpi_path) { '/path/to/cpi' }
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
    Validator::ExternalCpi.new(cpi_path, logger, cpi_task_log_path)
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

    it 'sets a director_uuid in the context' do
      allow(File).to receive(:executable?).with(cpi_path).and_return(cpi_path)

      subject.current_vm_id

      expect(Open3).to have_received(:capture3).with(anything, anything, contains_director_uuid('validator'))
    end
  end
end

RSpec::Matchers.define :contains_director_uuid do |value|
  match do |actual|
    request = JSON.load(actual[:stdin_data])
    request['context']['director_uuid'] == value
  end
end
