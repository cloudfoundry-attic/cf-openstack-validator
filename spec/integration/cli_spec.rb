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
    -r, --cpi-release RELEASE        CPI release .tgz path
    -s, --stemcell STEMCELL          Stemcell path
    -c, --config CONFIG_FILE         Configuration YAML file path
    -t, --tag TAG                    Run tests that match a specified RSpec tag (optional)
    -k, --skip-cleanup               Skip cleanup of OpenStack resources (optional)
    -v, --verbose                    Print more output for failing tests (optional)
    -f, --fail-fast                  Stop execution after the first test failure (optional)
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
    expect(stderr).to eq("Required options are missing: --cpi-release, --stemcell, --config\n")
    expect(stdout).to eq(help_text)
  end

end