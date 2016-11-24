require_relative '../../spec_helper'

module Validator::Cli
  describe CfOpenstackValidator do
    let(:working_dir) { tmp_path }
    let(:options) {{cpi_release: release_archive_path, stemcell: expand_project_path('spec/assets/dummy.tgz')}}
    let(:context) { Context.new(options, working_dir) }
    subject { CfOpenstackValidator.new(context) }

    let(:release_archive_path) { expand_project_path('spec/assets/cpi-release.tgz') }

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
        allow(subject).to receive(:check_installation)
        allow(subject).to receive(:prepare_ruby_environment)
        allow(subject).to receive(:generate_cpi_config)
        allow(subject).to receive(:print_gem_environment)
        allow(subject).to receive(:execute_specs)
      end
      context 'when ValidatorError is raised' do
        before(:each) do
          allow(subject).to receive(:check_installation).and_raise(ValidatorError.new('an-error-message'))
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
      it 'extracts the release and its packages' do
        subject.deep_extract_release(expand_project_path('spec/assets/cpi-release.tgz'))

        expect(File.exists?(File.join(working_dir, 'cpi-release/packages/bosh_openstack_cpi/bosh_openstack_cpi/dummy_bosh_openstack_cpi'))).to be(true)
        expect(File.exists?(File.join(working_dir, 'cpi-release/packages/ruby_openstack_cpi/ruby_openstack_cpi/dummy_ruby_openstack_cpi'))).to be(true)
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
      context 'when OPENSTACK_CPI_BIN is defined' do
        let(:cpi_path) {File.join(working_dir, 'provided-cpi')}
        before do
          ENV['OPENSTACK_CPI_BIN'] = cpi_path
        end
        after do
          ENV.delete('OPENSTACK_CPI_BIN')
        end

        context 'and the file exists' do
          before do
            File.write(cpi_path, '')
          end
          it 'skips the cpi installation' do
            subject.install_cpi_release

            expect(File.exists?(cpi_path)).to eq(true)
            expect(File.exists?(File.join(working_dir, 'cpi'))).to be(false)
          end

          it 'sets context.cpi_bin_path to OPENSTACK_CPI_BIN' do
            subject.install_cpi_release

            expect(context.cpi_bin_path).to eq(cpi_path)
          end
        end

        context 'and the file does not exists' do
          it 'raises error' do
            expect{
              subject.install_cpi_release
            }.to raise_error ValidatorError, "CPI executable is not found at OPENSTACK_CPI_BIN=#{context.openstack_cpi_bin_from_env}"
          end
        end
      end

      context 'when OPENSTACK_CPI_BIN is not defined' do
        it 'sets context.cpi_bin_path to default cpi_bin_path' do
          subject.install_cpi_release

          expect(context.cpi_bin_path).to eq(context.default_cpi_bin_path)
        end
      end

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
            subject.save_cpi_release_version
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
            File.write(File.join(context.working_dir, '.completed'), 'old-version')
          }

          it 'deletes and installs the cpi' do
            allow(File).to receive(:delete).and_call_original
            cpi_dir = FileUtils.mkdir_p(File.join(context.working_dir, 'cpi-release'))
            to_be_deleted_path = File.join(cpi_dir, 'should_be_deleted')
            cpi_bin_path = File.join(context.working_dir, 'cpi')
            File.write(to_be_deleted_path, '')
            File.write(cpi_bin_path, '')

            subject.install_cpi_release

            expect(File.exists?(to_be_deleted_path)).to be(false)
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
#!/usr/bin/env bash

BOSH_PACKAGES_DIR=\${BOSH_PACKAGES_DIR:-#{File.join(working_dir, 'packages')}}

PATH=\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin:\$PATH
export PATH

export BUNDLE_GEMFILE=\$BOSH_PACKAGES_DIR/bosh_openstack_cpi/Gemfile

bundle_cmd="\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin/bundle"
read -r INPUT
echo \$INPUT | \$bundle_cmd exec \$BOSH_PACKAGES_DIR/bosh_openstack_cpi/bin/openstack_cpi #{File.join(working_dir, 'cpi.json')}
EOF
      end
    end

    describe '#extract_stemcell' do
      let(:options) { {stemcell: expand_project_path('spec/assets/dummy.tgz')} }

      it ' deletes and extracts the stemcell' do
        stemcell_path = FileUtils.mkdir_p(File.join(working_dir, 'stemcell')).first
        to_be_deleted_path = File.join(stemcell_path, 'to_be_deleted')
        File.write(to_be_deleted_path, '')

        subject.extract_stemcell

        expect(File.exists?(to_be_deleted_path)).to be(false)
        expect(File.directory?(stemcell_path)).to be(true)
        expect(Dir.glob(File.join(stemcell_path, '*'))).to_not be_empty
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

    describe '#prepare_ruby_environment' do

      let(:status) { OpenStruct.new(:exitstatus => 0) }

      let(:context) { double('context', path_environment: '', gems_folder: '', bundle_command: '', working_dir: working_dir) }

      let(:env) do
        {
            'BUNDLE_CACHE_PATH' => 'vendor/package',
            'PATH' => context.path_environment,
            'GEM_PATH' => context.gems_folder,
            'GEM_HOME' => context.gems_folder
        }
      end

      it 'should execute bundle install' do
        allow(subject).to receive(:execute_command)

        subject.prepare_ruby_environment

        expect(subject).to have_received(:execute_command).with(
            hash_including(
                env: env,
                command: "#{context.bundle_command} install --local"
            )
        )
      end
    end

    describe '#generate_cpi_config' do
      let(:validator_config_path) { expand_project_path(File.join('spec', 'assets', 'validator.yml')) }

      let(:options) {{cpi_release: release_archive_path, config: validator_config_path}}

      it 'should generate cpi config and print out' do
        allow(Validator::Converter).to receive(:to_cpi_json).and_return([])

        expect{
          subject.generate_cpi_config
        }.to output(/CPI will use the following configuration/).to_stdout

        expect(File.exist?(File.join(working_dir, 'cpi.json'))).to eq(true)
        expect(Validator::Converter).to have_received(:to_cpi_json).with(Validator::Api::Configuration.new(validator_config_path).openstack)
      end

      context 'when config is invalid' do
        let(:validator_config_path) { Tempfile.new('validator.yml').path }

        after(:each) {File.delete(validator_config_path)}

        it 'should abort generation' do
          expect {
            subject.generate_cpi_config
          }.to raise_error(ValidatorError, /`validator.yml` is not valid:/)
        end
      end
    end

    describe '#print_gem_environment' do
      let(:context) { double('context', path_environment: 'path environment', gems_folder: 'gems_folder', bundle_command: 'command', working_dir: working_dir) }

      it 'should call command to print the gem environment and list of all gems' do
        path_environment = context.path_environment
        gems_folder = context.gems_folder
        env = {
            'PATH' => path_environment,
            'GEM_PATH' => gems_folder,
            'GEM_HOME' => gems_folder
        }
        allow(subject).to receive(:execute_command)

        subject.print_gem_environment

        expect(subject).to have_received(:execute_command).with(hash_including(
            env: env,
            command: 'command exec gem environment && command list'
        ))
      end
    end

    describe '#execute_specs' do
      let(:context) { double('context',
          path_environment: 'path environment', gems_folder: 'gems folder', bundle_command: 'command', working_dir: working_dir,
          cpi_release: release_archive_path, skip_cleanup?: true, verbose?: true, config: 'validator_config_path',
          validator_root_dir: expand_project_path(''), tag: nil, fail_fast?: false,
          cpi_bin_path: File.join(working_dir, 'cpi'))
      }
      let(:env) do
        {
          'PATH' => context.path_environment,
          'GEM_PATH' => context.gems_folder,
          'GEM_HOME' => context.gems_folder,
          'BOSH_PACKAGES_DIR' => File.join(working_dir, 'packages'),
          'BOSH_OPENSTACK_CPI_LOG_PATH' => File.join(working_dir, 'logs'),
          'BOSH_OPENSTACK_STEMCELL_PATH' => File.join(working_dir, 'stemcell'),
          'BOSH_OPENSTACK_CPI_PATH' => context.cpi_bin_path,
          'BOSH_OPENSTACK_VALIDATOR_CONFIG' => 'validator_config_path',
          'BOSH_OPENSTACK_CPI_CONFIG' => File.join(working_dir, 'cpi.json'),
          'BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP' => context.skip_cleanup?.to_s,
          'VERBOSE_FORMATTER' => context.verbose?.to_s,
          'http_proxy' => ENV['http_proxy'],
          'https_proxy' => ENV['https_proxy'],
          'no_proxy' => ENV['no_proxy'],
          'HOME' => ENV['HOME'],
          'EXCON_DEBUG' => 'true'
        }
      end
      let(:expected_command) {
        [
            "command exec rspec #{expand_project_path('src/specs')}",
            "--order defined",
            "--color --tty --require #{expand_project_path('lib/validator/formatter.rb')}",
            "--format Validator::TestsuiteFormatter",
            "2> #{File.join(working_dir, 'logs', 'testsuite.log')}"
        ].join(" ")
      }

      it 'should execute specs' do
        allow(Open3).to receive(:popen3)

        subject.execute_specs

        expect(Open3).to have_received(:popen3).with(env, expected_command, unsetenv_others: true)
      end

      it 'sets EXCON_DEBUG to log fog to STDERR' do
        allow(Open3).to receive(:popen3)

        subject.execute_specs

        expect(Open3).to have_received(:popen3).with(hash_including('EXCON_DEBUG' => 'true'), any_args)
      end

      it 'should write the stdout to stdout' do
        allow(Open3).to receive(:popen3).and_yield('', 'we write stdout to stdout', [''], OpenStruct.new(:value => 0))

        expect{
          subject.execute_specs
        }.to output("we write stdout to stdout").to_stdout
      end

      context 'when execution fails' do
        it 'raises an error' do
          allow(Open3).to receive(:popen3).and_yield('', '', '', OpenStruct.new(:value => 1))

          expect{
            subject.execute_specs
          }.to raise_error do |e|
            expect(e).to be_a(ErrorWithLogDetails)
            expect(e.message).to include("exec rspec")
            expect(e.log_path).to eq(File.join(working_dir, 'logs', 'testsuite.log'))
          end
        end
      end

      context 'when option are set' do
        let(:context) { double('context',
            path_environment: 'path environment', gems_folder: 'gems folder', bundle_command: 'command', working_dir: working_dir,
            cpi_release: release_archive_path, skip_cleanup?: true, verbose?: true, config: 'validator_config_path',
            validator_root_dir: expand_project_path(''), tag: 'focus', fail_fast?: true,
            cpi_bin_path: File.join(working_dir, 'cpi'))
        }
        let(:expected_command) {
          [
              "command exec rspec #{expand_project_path('src/specs')}",
              '--tag focus',
              '--fail-fast',
              '--order defined',
              "--color --tty --require #{expand_project_path('lib/validator/formatter.rb')}",
              '--format Validator::TestsuiteFormatter',
              "2> #{File.join(working_dir, 'logs', 'testsuite.log')}"
          ].join(' ')
        }
        it 'should execute specs with fail fast option' do
          allow(Open3).to receive(:popen3)

          subject.execute_specs

          expect(Open3).to have_received(:popen3).with(env, expected_command, unsetenv_others: true)
        end
      end
    end

    describe '#check_installation' do
      before(:each) do
        File.write(File.join(working_dir, '.completed'), release_archive_path)
      end

      after(:each) do
        File.delete(File.join(working_dir, '.completed')) if File.exist?(File.join(working_dir, '.completed'))
      end

      context 'when installation succeeded' do
        it 'does not raise a ValidationError' do
          expect{
            subject.check_installation
          }.to_not raise_error
        end
      end

      context 'when the installation failed' do
        let(:expected_message) {
          "The CPI installation did not finish successfully.\n" +
          "Execute 'rm -rf #{working_dir}' and run the tests again."
        }
        it 'raises a ValidationError' do
          File.delete(File.join(working_dir, '.completed'))
          expect{
            subject.check_installation
          }.to raise_error ValidatorError, expected_message
        end
      end
    end

    describe '#save_cpi_release_version' do
      it 'writes a .completed file with the cpi version' do
        allow(context).to receive(:cpi_release).and_return('cpi version')

        subject.save_cpi_release_version

        expect(File.exists?(File.join(working_dir, '.completed'))).to eq(true)
        expect(File.read(File.join(working_dir, '.completed'))).to eq('cpi version')
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
          package_order = subject.release_packages(@package_dir, ['common_package', 'missing_package'])

          expect(package_order).to eq([@common_package_path, @a_dummy_package_path, @second_dummy_package_path])
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
  end
end