require 'rspec'
require 'open3'

def run_validator(args)
  bin_path = File.expand_path('../../../bin', __FILE__)
  cmd = "#{bin_path}/cf-openstack-validator #{args}"
  Open3.capture3(cmd)
end

def help_text
  <<EOT
Usage: cf-openstack-validator [options]
    -h, --help                       Prints this help
    -r, --cpi-release RELEASE        CPI release .tgz path. Latest version will be downloaded if not specified (optional)
    -s, --stemcell STEMCELL          Stemcell path
    -c, --config CONFIG_FILE         Configuration YAML file path
    -t, --tag TAG                    Run tests that match a specified RSpec tag. To run only CPI API tests use "cpi_api" as the tag (optional)
    -k, --skip-cleanup               Skip cleanup of OpenStack resources (optional)
    -v, --verbose                    Print more output for failing tests (optional)
    -f, --fail-fast                  Stop execution after the first test failure (optional)
    -w, --working-dir WORKING_DIR    Working directory for running the tests (optional)
EOT
end

describe 'Command Line' do

  it 'should show help' do
    stdout, stderr, exit_code = run_validator('--help')
    expect(exit_code).to eq(0)
    expect(stdout).to eq(help_text)
    expect(stderr).to eq('')
  end

  it 'checks for required options' do
    stdout, stderr, exit_code = run_validator('')
    expect(exit_code.exitstatus).to eq(1)
    expect(stderr).to eq("Required options are missing: --stemcell, --config\n")
    expect(stdout).to eq(help_text)
  end

  context 'when all required parameters are given' do
    it 'returns an error if stemcell and/or config do not exist' do
      stdout, stderr, exit_code = run_validator('--stemcell invalid-stemcell --config invalid-config')
      expect(exit_code.exitstatus).to eq(1)
      expect(stderr).to  include("No such file or directory")
    end
  end
end