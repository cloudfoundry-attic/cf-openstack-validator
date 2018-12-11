require_relative '../../spec_helper'
require 'tempfile'

module Validator::Cli
  describe CfOpenstackValidator do
    let(:working_dir) { tmp_path }
    let(:jobs_config_path) { File.join(working_dir, 'jobs', 'openstack_cpi', 'config') }

    let(:options) {{cpi_release: release_archive_path, stemcell: expand_project_path('spec/assets/dummy.tgz')}}
    let(:default_options) {{working_dir: working_dir}}
    let(:context) { Context.new(options.merge(default_options)) }
    subject { CfOpenstackValidator.new(context) }

    let(:release_archive_path) { expand_project_path('spec/assets/cpi-release.tgz') }
    let(:release_archive_sha1) { Digest::SHA1.file(expand_project_path('spec/assets/cpi-release.tgz')) }

    before(:each) do
      allow($stdout).to receive(:puts)
      FileUtils.mkdir_p(working_dir)
    end

    after(:each) do
      if File.exists?(working_dir)
        FileUtils.rm_r(working_dir)
      end
    end

    describe '#run' do
      before(:each) do
        allow(subject).to receive(:print_working_dir)
        allow(subject).to receive(:cleanup_logs)
        allow(subject).to receive(:check_installation)
        allow(subject).to receive(:prepare_ruby_environment)
        allow(subject).to receive(:validate_config)
        allow(subject).to receive(:generate_cpi_config)
        allow(subject).to receive(:print_gem_environment)
        allow(subject).to receive(:execute_specs)
      end

      context 'when ErrorWithLogDetails error is raised' do
        before(:each) do
          allow(subject).to receive(:execute_specs).and_raise(ErrorWithLogDetails.new('Error executing specs', 'a-log-path'))
        end

        it 'exits process with exit code 1' do
          allow(STDERR).to receive(:puts)
          expect {
            subject.run
          }.to raise_error{ |error|
            expect(error).to be_a(SystemExit)
            expect(error.status).to eq(1)
          }
        end

        it 'writes the log_path to STDERR' do
          allow(Kernel).to receive(:exit)

          expect {
            subject.run
          }.to output(/a-log-path/).to_stderr
        end
      end
     end

    describe '#deep_extract_release' do
      it 'extracts the release and its packages and jobs' do
        subject.deep_extract_release(expand_project_path('spec/assets/cpi-release.tgz'))

        expect(File.exists?(File.join(working_dir, 'cpi-release/packages/bosh_openstack_cpi/bosh_openstack_cpi/dummy_bosh_openstack_cpi'))).to be(true)
        expect(File.exists?(File.join(working_dir, 'cpi-release/packages/ruby_openstack_cpi/ruby_openstack_cpi/dummy_ruby_openstack_cpi'))).to be(true)
        expect(File.exists?(File.join(working_dir, 'cpi-release/jobs/openstack_cpi/templates/cpi.erb'))).to be(true)
      end
    end

    describe '#compile_package' do
      let(:package_path) { expand_project_path('spec/assets/cpi-release/packages/dummy_package') }
      let(:release_archive_path) { expand_project_path('spec/assets/cpi-release') }
      let(:compiled_package_dir) { File.join(working_dir, 'packages', 'dummy_package') }

      before(:each) { allow($stdout).to receive(:puts) }

      it 'creates package folder' do
        subject.compile_package(package_path)

        expect(File.exists?(File.join(working_dir, 'packages/dummy_package'))).to be(true)
      end

      it 'executes packaging script' do
        subject.compile_package(package_path)

        compiled_file_path = File.join(working_dir, 'packages/dummy_package', 'compiled_file')
        expect(File.exists?(compiled_file_path)).to be(true)
        compiled_packages_dir = File.join(working_dir, 'packages')
        expect(File.read(compiled_file_path)).to eq("#{compiled_package_dir}\n#{compiled_packages_dir}\n")
      end

      it 'writes log file' do
        subject.compile_package(package_path)

        logfile = File.join(working_dir, 'logs', 'packaging-dummy_package.log')
        expect(File.exists?(logfile)).to be(true)
        expect(File.read(logfile)).to eq("Log to STDOUT\nLog to STDERR\n")
      end

      it 'writes message to stdout' do
        expect {
          subject.compile_package(package_path)
        }.to output("Compiling package 'dummy_package' into '#{compiled_package_dir}'\n").to_stdout
      end

      context 'when the packaging script fails' do
        let(:package_path) { expand_project_path('spec/assets/broken-cpi-release/packages/broken_package') }

        it 'raises an error with log details' do
          expect{
            subject.compile_package(package_path)
          }.to raise_error do |e|
            expect(e).to be_a(ErrorWithLogDetails)
            expect(e.message).to include("Executing '#{package_path}/packaging' failed")
            expect(e.log_path).to eq(File.join(working_dir, 'logs', 'packaging-broken_package.log'))
          end
        end
      end
    end

    describe '#install_cpi_release' do
      context 'when there is no cpi installed' do
        it 'compiles packages and renders cpi executable' do
          subject.install_cpi_release

          verify_cpi_installation
        end
      end

      context 'when there is an cpi installed' do
        context 'when the installed cpi version matches the given version' do
          let(:release_archive_path) { expand_project_path('spec/assets/cpi-release.tgz') }

          before(:each) do
            FileUtils.mkdir_p(context.extracted_cpi_release_dir)
            File.write(File.join(context.extracted_cpi_release_dir, '.completed'), release_archive_sha1)
          end

          it 'does not re-install the cpi' do
            allow(subject).to receive(:deep_extract_release)

            subject.install_cpi_release

            expect(subject).to_not have_received(:deep_extract_release)
          end
        end

        context 'when the installed cpi version does not match the given version' do
          let(:release_archive_path) { expand_project_path('spec/assets/cpi-release.tgz') }

          before(:each){
            FileUtils.mkdir_p(context.extracted_cpi_release_dir)
            File.write(File.join(context.extracted_cpi_release_dir, '.completed'), 'old-sha1')
          }

          it 'deletes and installs the cpi' do
            allow(File).to receive(:delete).and_call_original
            cpi_dir = FileUtils.mkdir_p(File.join(context.working_dir, 'cpi-release'))
            to_be_deleted_path = File.join(cpi_dir, 'should_be_deleted')
            packages_dir = FileUtils.mkdir_p(File.join(context.working_dir, 'packages'))
            package_to_be_deleted = File.join(packages_dir, 'some-package')
            cpi_bin_path = File.join(context.working_dir, 'cpi')
            File.write(to_be_deleted_path, '')
            File.write(cpi_bin_path, '')
            File.write(package_to_be_deleted, '')

            subject.install_cpi_release

            expect(File.exists?(to_be_deleted_path)).to be(false)
            expect(File.exists?(package_to_be_deleted)).to be(false)
            expect(File.read(cpi_bin_path)).to_not eq('')
            expect(File).to have_received(:delete).with(cpi_bin_path)
            verify_cpi_installation
          end
        end
      end

      def verify_cpi_installation
        expect(File.exists?(File.join(working_dir, 'cpi-release/packages/bosh_openstack_cpi/bosh_openstack_cpi/dummy_bosh_openstack_cpi'))).to be(true)
        expect(File.exists?(File.join(working_dir, 'cpi-release/packages/ruby_openstack_cpi/ruby_openstack_cpi/dummy_ruby_openstack_cpi'))).to be(true)

        expect(File.exists?(File.join(working_dir, 'packages', 'bosh_openstack_cpi'))).to be(true)
        expect(File.exists?(File.join(working_dir, 'packages', 'ruby_openstack_cpi'))).to be(true)

        rendered_cpi_executable = File.join(working_dir, 'cpi')
        expect(File.exists?(rendered_cpi_executable)).to be(true)
        expect(File.executable?(rendered_cpi_executable)).to be(true)
        expect(File.read(rendered_cpi_executable)).to eq <<EOF
#!/bin/bash

set -e







BOSH_PACKAGES_DIR=${BOSH_PACKAGES_DIR:-/var/vcap/packages}
BOSH_JOBS_DIR=${BOSH_JOBS_DIR:-/var/vcap/jobs}

PATH=$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin:$PATH
export PATH
export HOME=~

export BUNDLE_GEMFILE=$BOSH_PACKAGES_DIR/bosh_openstack_cpi/Gemfile

bundle_cmd="$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin/bundle"

exec $bundle_cmd exec $BOSH_PACKAGES_DIR/bosh_openstack_cpi/bin/openstack_cpi \\
  $BOSH_JOBS_DIR/openstack_cpi/config/cpi.json \\
  $BOSH_JOBS_DIR/openstack_cpi/config/cacert.pem
EOF
      end
    end

    describe '#extract_stemcell' do
      let(:stemcell) { expand_project_path('spec/assets/dummy.tgz') }
      let(:options) { {stemcell: stemcell} }

      it ' deletes and extracts the stemcell' do
        stemcell_path = FileUtils.mkdir_p(File.join(working_dir, 'stemcell')).first
        to_be_deleted_path = File.join(stemcell_path, 'to_be_deleted')
        File.write(to_be_deleted_path, '')

        subject.extract_stemcell

        expect(File.exists?(to_be_deleted_path)).to be(false)
        expect(File.directory?(stemcell_path)).to be(true)
        expect(Dir.glob(File.join(stemcell_path, '*'))).to_not be_empty
      end

      context 'when stemcell already extracted' do
        it 'skips extraction' do
          stemcell_path = FileUtils.mkdir_p(File.join(working_dir, 'stemcell')).first
          stemcell_sha1 = Digest::SHA1.file(stemcell).to_s
          File.write(File.join(stemcell_path, '.completed'), stemcell_sha1)

          expect{
            subject.extract_stemcell
          }.to output(/is already extracted to/).to_stdout
        end
      end
    end

    describe '#execute_command' do
      it 'writes output to logfile' do
        log_directory = File.join(working_dir, 'logs')
        logfile = File.join(log_directory, 'logfile.log')
        FileUtils.mkdir_p(log_directory)

        subject.execute_command(
           env: {},
           command: "echo 'bundle log'",
           log_path: logfile
        )

        expect(File.exists?(logfile)).to be(true)
        expect(File.read(logfile)).to eq("bundle log\n")
      end

      context 'when command fails' do
        it 'throws exception' do
          expect {
            subject.execute_command(
                env: {},
                command: "ls /non-existing-dir",
                log_path: "/dev/null"
            )
          } .to raise_error do |e|
            expect(e).to be_a(Validator::Cli::ErrorWithLogDetails)
            expect(e.message).to include('ls /non-existing-dir')
            expect(e.log_path).to eq('/dev/null')
          end
        end
      end
    end

    describe '#validate_config' do
      let(:validator_config_file) { Tempfile.new('validator.yml') }

      after(:each) { validator_config_file.delete }

      let(:options) {{cpi_release: release_archive_path, config_path: validator_config_file.path}}

      context 'when config is invalid' do
        it 'should abort generation' do
          expect {
            subject.validate_config
          }.to raise_error(Validator::Api::ValidatorError, /`validator.yml` is not valid:/)
        end
      end

      context 'when extensions path does not exist' do
        before(:each) do
          File.write(validator_config_file.path,YAML.dump(read_valid_config.merge({
            'extensions' => { 'paths' => ['non-existing-dir'] }
          })))
        end

        it 'raises an error' do
          expected_path = File.join(File.dirname(context.config_path), 'non-existing-dir')

          expect {
            subject.validate_config
          }.to raise_error(Validator::Api::ValidatorError, "Extension path '#{expected_path}' is not a directory.")
        end
      end
    end

    describe '#generate_cpi_config' do
      let(:validator_config_path) { expand_project_path(File.join('spec', 'assets', 'validator.yml')) }

      let(:options) {{cpi_release: release_archive_path, config_path: validator_config_path}}

      let(:cpi_config_path) { File.join(working_dir, 'jobs/openstack_cpi/config/cpi.json') }

      it 'should generate cpi config and print out' do
        allow(Validator::Converter).to receive(:to_cpi_json).and_return({})

        expect {
          subject.generate_cpi_config
        }.to output(/CPI will use the following configuration/).to_stdout

        expect(File.exist?(cpi_config_path)).to eq(true)
        expect(Validator::Converter).to have_received(:to_cpi_json).with(Validator::Api::Configuration.new(validator_config_path).openstack).twice
      end

      it 'redacts the api_key in the output, but not in the config file' do
        expect {
          subject.generate_cpi_config
        }.to output(/"api_key": "<redacted>"/).to_stdout

        cpi_config = JSON.parse(File.read(cpi_config_path))

        expect(cpi_config['cloud']['properties']['openstack']['api_key']).to eq('password')
      end

    end

    describe '#execute_specs' do
      let(:verbose) { true }
      let(:skip_cleanup) { true }

      let(:context) { double('context',
          path_environment: 'path environment', gems_folder: 'gems folder', bundle_command: 'command', working_dir: working_dir,
          cpi_release: release_archive_path, skip_cleanup?: skip_cleanup, verbose?: verbose, config_path: 'validator_config_path',
          validator_root_dir: expand_project_path(''), tag: nil, fail_fast?: false,
          cpi_bin_path: File.join(working_dir, 'cpi'), create_validator_options: validator_options,
          jobs_config_path: jobs_config_path,
          cacert_path: File.join(jobs_config_path, 'cacert.pem'))
      }
      let(:validator_options) { Validator::Cli::Options.new }

      let(:spec_formatter_path) { File.join(context.validator_root_dir, 'lib', 'validator', 'formatter.rb') }
      let(:expected_command) {
        args = [
            '--order', 'defined', '--color', '--tty',
            '--require', "#{spec_formatter_path}",
            '--format', 'Validator::TestsuiteFormatter',
        ]
        args += Dir.glob('src/specs/*_spec.rb')
        args
      }

      let(:config) { double(RSpec::Core::Configuration, :add_setting => nil, :options= => nil) }

      before(:each) {
        allow(RSpec).to receive(:configure).and_yield(config)
      }

      it 'should execute specs with rspec environment' do
        allow(RSpec::Core::Runner).to receive(:run).and_return(0)

        subject.execute_specs

        expect(RSpec::Core::Runner).to have_received(:run).with(expected_command, anything, $stdout)
        expect(config).to have_received(:add_setting).with(:options)
        expect(config).to have_received(:options=).with(validator_options)
      end

      context 'when execution fails' do
        it 'raises an error' do
          allow(RSpec::Core::Runner).to receive(:run).and_return(1)

          expect{
            subject.execute_specs
          }.to raise_error do |e|
            expect(e).to be_a(ErrorWithLogDetails)
            expect(e.message).to include("Running 'RSpec::Core::Runner.run' with arguments")
            expect(e.log_path).to eq(File.join(working_dir, 'logs', 'testsuite.log'))
          end
        end
      end

      context 'when option are set' do
        let(:context) { double('context',
            path_environment: 'path environment', gems_folder: 'gems folder', bundle_command: 'command', working_dir: working_dir,
            cpi_release: release_archive_path, skip_cleanup?: true, verbose?: true, config_path: 'validator_config_path',
            validator_root_dir: expand_project_path(''), tag: 'focus', fail_fast?: true,
            cpi_bin_path: File.join(working_dir, 'cpi'), create_validator_options: validator_options,
            jobs_config_path: jobs_config_path,
            cacert_path: File.join(jobs_config_path, 'cacert.pem'))
        }

        it 'should execute specs with fail fast option' do
          allow(RSpec::Core::Runner).to receive(:run).and_return(0)

          subject.execute_specs

          expect(RSpec::Core::Runner).to have_received(:run).with(array_including('--fail-fast'), anything, anything)
        end
      end
    end

    describe '#release_packages' do
      before(:each) do
        @package_dir = Dir.mktmpdir
        @common_package_path = File.join(@package_dir, 'packages', 'common_package')
        @a_dummy_package_path = File.join(@package_dir, 'packages', 'a_dummy_package')
        @second_dummy_package_path = File.join(@package_dir, 'packages', 'second_dummy_package')
        FileUtils.mkdir(File.join(@package_dir, 'packages'))
        FileUtils.mkdir(@common_package_path)
        FileUtils.mkdir(@a_dummy_package_path)
        FileUtils.mkdir(@second_dummy_package_path)
      end

      after(:each) do
        FileUtils.rm_rf(@package_dir)
      end

      it 'should list all packages' do
        package_order = subject.release_packages(@package_dir)

        expect(package_order).to contain_exactly(@a_dummy_package_path, @common_package_path, @second_dummy_package_path)
      end

      context 'when packages have dependencies' do
        it 'should list all packages in the right order' do
          package_order = subject.release_packages(@package_dir, ['common_package', 'second_dummy_package'])

          expect(package_order).to eq([@common_package_path, @second_dummy_package_path, @a_dummy_package_path])
        end
      end

      context 'when a dependency is missing' do
        it 'should list all packages in the right order without the missing package' do
          expected_package_order_1 = [@common_package_path, @a_dummy_package_path, @second_dummy_package_path]
          expected_package_order_2 = [@common_package_path, @second_dummy_package_path, @a_dummy_package_path]

          package_order = subject.release_packages(@package_dir, ['common_package', 'missing_package'])

          expect(package_order).to eq(expected_package_order_1).or eq(expected_package_order_2)
        end
      end
    end

    describe '#print_working_dir' do
      it 'prints the working dir' do
        expect{
          subject.print_working_dir
        }.to output("Using '#{context.working_dir}' as working directory\n").to_stdout
      end
    end

    describe '#download_cpi_release' do
      let(:download_url) { 'https://bosh.io/d/github.com/cloudfoundry/bosh-openstack-cpi-release' }
      let(:expected_cpi_release_path) { File.join(context.working_dir, 'cpi-release-download') }
      let(:downloaded_temp_file_path) { File.join(working_dir, 'cpi.tgz') }

      before(:each){
        File.write(File.new(downloaded_temp_file_path, 'w'), 'some-response')
      }

      it 'downloads the cpi with the name given into working_dir' do
        allow(subject).to receive(:open).with(download_url).and_return(downloaded_temp_file_path)

        subject.download_cpi_release(download_url, expected_cpi_release_path)

        expect(subject).to have_received(:open).with(download_url)
        expect(File.exists?(expected_cpi_release_path)).to be true
        expect(File.read(expected_cpi_release_path)).to eq('some-response')
      end

      context 'when cpi release already exists in working_dir' do
        it 'downloads cpi and overrides existing one' do
          File.write(File.new(expected_cpi_release_path, 'w'), 'some-old-version-of-cpi')
          allow(subject).to receive(:open).with(download_url).and_return(downloaded_temp_file_path)

          subject.download_cpi_release(download_url, expected_cpi_release_path)

          expect(subject).to have_received(:open).with(download_url)
          expect(File.read(expected_cpi_release_path)).to eq('some-response')
        end
      end
    end

  describe '#prepare_cpi_release' do
      context 'when cpi-release option is specified' do
        it 'installs cpi' do
          allow(subject).to receive(:install_cpi_release)
          allow(subject).to receive(:add_cpi_bin_env)
          allow(subject).to receive(:download_cpi_release)

          subject.prepare_cpi_release

          expect(subject).to have_received(:install_cpi_release)
          expect(subject).to_not have_received(:add_cpi_bin_env)
          expect(subject).to_not have_received(:download_cpi_release)
        end
      end

      context 'when cpi-release option is not specified' do
        let(:release_archive_path) { }

        context 'when OPENSTACK_CPI_BIN environment variable is set to a valid cpi release' do
          before(:each) do
            allow(subject).to receive(:cpi_bin_env?).and_return(true)
          end

          it 'adds cpi binary location to the context' do
            allow(subject).to receive(:install_cpi_release)
            allow(subject).to receive(:add_cpi_bin_env)
            allow(subject).to receive(:download_cpi_release)

            subject.prepare_cpi_release

            expect(subject).to have_received(:add_cpi_bin_env)
            expect(subject).to_not have_received(:install_cpi_release)
            expect(subject).to_not have_received(:download_cpi_release)
          end
        end

        context 'when OPENSTACK_CPI_BIN environment variable is not set' do
          before(:each) do
            allow(subject).to receive(:openstack_cpi_bin_is_valid?).and_return(false)
          end

          it 'adds cpi binary location to the context' do
            allow(subject).to receive(:install_cpi_release)
            allow(subject).to receive(:add_cpi_bin_env)
            allow(subject).to receive(:install_cpi_release_from_config)

            subject.prepare_cpi_release

            expect(subject).to have_received(:install_cpi_release_from_config)
            expect(subject).to_not have_received(:install_cpi_release)
            expect(subject).to_not have_received(:add_cpi_bin_env)
          end
        end
      end
    end

    describe '#add_cpi_bin_env' do
      context 'when OPENSTACK_CPI_BIN is defined' do
        let(:cpi_path) {File.join(working_dir, 'provided-cpi')}
        before(:each) do
          ENV['OPENSTACK_CPI_BIN'] = cpi_path
        end
        after do
          ENV.delete('OPENSTACK_CPI_BIN')
        end

        context 'and the file exists' do
          before(:each) do
            File.write(cpi_path, '')
          end

          it 'sets context.cpi_bin_path to OPENSTACK_CPI_BIN' do
            subject.add_cpi_bin_env

            expect(context.cpi_bin_path).to eq(cpi_path)
          end
        end

        context 'and the given path is a folder' do
          before(:each) do
            FileUtils.mkdir_p(cpi_path)
          end

          it 'raises error' do
            expect{
              subject.add_cpi_bin_env
            }.to raise_error Validator::Api::ValidatorError, "OPENSTACK_CPI_BIN points to a folder and not an executable. (#{context.openstack_cpi_bin_from_env})"
          end
        end

        context 'and the file does not exists' do
          it 'raises error' do
            expect{
              subject.add_cpi_bin_env
            }.to raise_error Validator::Api::ValidatorError, "CPI executable is not found at OPENSTACK_CPI_BIN=#{context.openstack_cpi_bin_from_env}"
          end
        end
      end
    end

    describe '#install_cpi_release_from_config' do
      let(:validator_config_path) { expand_project_path(File.join('spec', 'assets', 'validator.yml')) }
      let(:options) {{config_path: validator_config_path}}
      let(:expected_sha1) { 'cpi-sha1' }
      let(:expected_cpi_release_path) { File.join(working_dir, 'bosh-openstack-cpi-release.tgz') }

      before do
        allow(subject).to receive(:download_cpi_release).and_return(expected_cpi_release_path)
        allow(Digest::SHA1).to receive(:file).and_return(expected_sha1)
        allow(subject).to receive(:install_cpi_release)
      end

      context 'when download state file exists' do
        context 'if cpi was successfully downloaded from same url before' do
          before do
            File.write(File.join(working_dir, '.download_completed'), 'cpi-download-url')
          end

          context 'without errors' do

            it 'downloads cpi, sets path, and installs cpi' do
              expect {
                subject.install_cpi_release_from_config
              }.to_not raise_error

              expect(subject).to_not have_received(:download_cpi_release)
              expect(context.cpi_release_path).to eq(expected_cpi_release_path)
              expect(subject).to have_received(:install_cpi_release)
              expect(File.read(File.join(working_dir, '.download_completed'))).to eq('cpi-download-url')
            end
          end

          context 'when sha1 does not match' do
            before do
              allow(Digest::SHA1).to receive(:file).and_return('invalid-sha1')
            end

            it 'raises error' do
              expect {
                subject.install_cpi_release_from_config
              }.to raise_error(Validator::Api::ValidatorError, "Configured SHA1 '#{expected_sha1}' does not match downloaded CPI SHA1 'invalid-sha1'")
            end
          end

        end

        context 'if cpi was downloaded from different URL before' do
          before do
            File.write(File.join(working_dir, '.download_completed'), 'previous-cpi-download-url')
          end

          context 'without errors' do

            it 'downloads cpi, sets path, and installs cpi' do
              expect {
                subject.install_cpi_release_from_config
              }.to_not raise_error

              expect(subject).to have_received(:download_cpi_release).with('cpi-download-url', expected_cpi_release_path)
              expect(context.cpi_release_path).to eq(expected_cpi_release_path)
              expect(subject).to have_received(:install_cpi_release)
              expect(File.read(File.join(working_dir, '.download_completed'))).to eq('cpi-download-url')
            end
          end

          context 'when sha1 does not match' do
            before do
              allow(Digest::SHA1).to receive(:file).and_return('invalid-sha1')
            end

            it 'raises error' do
              expect {
                subject.install_cpi_release_from_config
              }.to raise_error(Validator::Api::ValidatorError, "Configured SHA1 '#{expected_sha1}' does not match downloaded CPI SHA1 'invalid-sha1'")
            end
          end
        end
      end

      context 'if no download state file exists' do
        context 'without errors' do

          it 'downloads cpi, sets path, and installs cpi' do
            expect {
              subject.install_cpi_release_from_config
            }.to_not raise_error

            expect(subject).to have_received(:download_cpi_release).with('cpi-download-url', expected_cpi_release_path)
            expect(context.cpi_release_path).to eq(expected_cpi_release_path)
            expect(subject).to have_received(:install_cpi_release)
            expect(File.read(File.join(working_dir, '.download_completed'))).to eq('cpi-download-url')
          end
        end

        context 'when sha1 does not match' do
          before do
            allow(Digest::SHA1).to receive(:file).and_return('invalid-sha1')
          end

          it 'raises error' do
            expect {
              subject.install_cpi_release_from_config
            }.to raise_error(Validator::Api::ValidatorError, "Configured SHA1 '#{expected_sha1}' does not match downloaded CPI SHA1 'invalid-sha1'")
          end
        end
      end
    end

    describe '#cleanup_logs' do
      let(:log_path) { File.join(working_dir, 'logs') }

      context 'when stats.log already exists' do

        before do
          FileUtils.mkdir_p(log_path)
          File.write(File.join(log_path, 'stats.log'), 'extreme performance')
        end

        it 'deletes <logpath>/stats.log' do
          subject.cleanup_logs
          expect(File.exists?(File.join(log_path, 'stats.log'))).to be(false)
        end

      end

      context 'when stats.log does not exist' do
        it 'does not' do
          subject.cleanup_logs
          expect(File.exists?(File.join(log_path, 'stats.log'))).to be(false)
        end
      end

    end
  end
end
