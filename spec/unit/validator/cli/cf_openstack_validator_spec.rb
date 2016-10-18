require_relative '../../spec_helper'

module Validator::Cli
  describe CfOpenstackValidator do
    let(:working_dir) { tmp_path }
    let(:options) {{working_dir: working_dir, cpi_release: release_archive_path}}
    let(:context) { Context.new(options) }
    subject { CfOpenstackValidator.new(context) }

    let(:release_archive_path) { expand_project_path('spec/assets/cpi-release.tgz') }

    before(:each) do
      FileUtils.mkdir_p(working_dir)
    end

    after(:each) do
      if File.exists?(working_dir)
        FileUtils.rm_r(working_dir)
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
      it 'creates package folder' do
        subject.compile_package(package_path)

        expect(File.exists?(File.join(working_dir, 'packages/dummy_package'))).to be(true)
      end

      it 'executes packaging script' do
        subject.compile_package(package_path)

        compiled_file_path = File.join(working_dir, 'packages/dummy_package', 'compiled_file')
        expect(File.exists?(compiled_file_path)).to be(true)
        compiled_package_dir = File.join(working_dir, 'packages', 'dummy_package')
        compiled_packages_dir = File.join(working_dir, 'packages')
        expect(File.read(compiled_file_path)).to eq("#{compiled_package_dir}\n#{compiled_packages_dir}\n")
      end

      it 'writes log file' do
        subject.compile_package(package_path)

        logfile = File.join(working_dir, 'logs', 'packaging-dummy_package.log')
        expect(File.exists?(logfile)).to be(true)
        expect(File.read(logfile)).to eq("Log to STDOUT\nLog to STDERR\n")
      end

      context 'when the packaging script fails' do
        let(:package_path) { expand_project_path('spec/assets/broken-cpi-release/packages/broken_package') }

        it 'raises an error with log details' do
          expect{
            subject.compile_package(package_path)
          }.to raise_error(ErrorWithLogDetails)
        end
      end
    end

    describe '#install_cpi_release' do
      it 'compiles packages and renders cpi executable' do
        subject.install_cpi_release

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
      let(:options) { {working_dir: working_dir, stemcell: expand_project_path('spec/assets/dummy.tgz')} }

      it 'should extract the stemcell' do
        subject.extract_stemcell

        extracted_stemcell = File.join(working_dir, 'stemcell')

        expect(File.directory?(extracted_stemcell)).to be(true)
        expect(Dir.glob(File.join(extracted_stemcell, '*'))).to_not be_empty
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
        allow(Open3).to receive(:capture2e).and_return(['', status])

        subject.prepare_ruby_environment

        expect(Open3).to have_received(:capture2e).with(env, "#{context.bundle_command} install --local", unsetenv_others: true)
      end

      it 'should write log to `bundle_install.log` file' do
        allow(Open3).to receive(:capture2e).and_return(['bundle log', status])

        subject.prepare_ruby_environment

        logfile = File.join(working_dir, 'logs', 'bundle_install.log')
        expect(File.exists?(logfile)).to be(true)
        expect(File.read(logfile)).to eq('bundle log')
      end

      context 'when `bundle install` fails' do
        let(:status) { OpenStruct.new(:exitstatus => 1) }

        it 'raises an error with log details' do
          allow(Open3).to receive(:capture2e).and_return(['error', status])

          expect {
            subject.prepare_ruby_environment
          }.to raise_error(ErrorWithLogDetails)
        end
      end
    end

    describe '#generate_cpi_config' do
      let(:validator_config_path) { expand_project_path(File.join('spec', 'assets', 'validator.yml')) }

      before(:each) do
        #Validator::Configuration is a singleton that is why we need to mock it here for the tests
        allow(CfValidator).to receive(:configuration).and_return(Validator::Configuration.new(validator_config_path))
      end

      it 'should generate cpi config and print out' do
        allow(Converter).to receive(:to_cpi_json).and_return([])

        expect{
          subject.generate_cpi_config
        }.to output(/CPI will use the following configuration/).to_stdout

        expect(File.exist?(File.join(working_dir, 'cpi.json'))).to eq(true)
        expect(Converter).to have_received(:to_cpi_json).with(CfValidator.configuration.openstack)
      end

      context 'when config is invalid' do
        let(:validator_config_path) { Tempfile.new('validator.yml').path }

        after(:each) {File.delete(validator_config_path)}

        it 'should abort generation' do
          ok, error = subject.generate_cpi_config
          expect(ok).to eq(false)
          expect(error).to match(/`validator.yml` is not valid:/)
        end
      end
    end

    describe '#print_gem_environment' do
      let(:context) { double('context', path_environment: 'path environment', gems_folder: 'gems_folder', bundle_command: 'command', working_dir: working_dir) }

      it 'should print the gem environment and list of all gems' do
        bundle_command = context.bundle_command
        path_environment = context.path_environment
        gems_folder = context.gems_folder
        env = {
            'PATH' => path_environment,
            'GEM_PATH' => gems_folder,
            'GEM_HOME' => gems_folder
        }
        gems_log_content = "it prints gems environment\nGems included by the bundle:"
        allow(Open3).to receive(:capture2e).and_return([gems_log_content, OpenStruct.new(:exitstatus => 0)])


        subject.print_gem_environment

        expect(Open3).to have_received(:capture2e).with(env, 'command exec gem environment && command list', unsetenv_others: true)
        expect(File.exist?(File.join(working_dir, 'logs', 'gem_environment.log'))).to eq(true)
        expect(File.read(File.join(working_dir, 'logs', 'gem_environment.log'))).to eq(gems_log_content)
      end

      context 'when print fails' do
        let(:context) { double('context', path_environment: '', gems_folder: '', bundle_command: '', working_dir: working_dir)}
        it 'should raise exception' do
          allow(Open3).to receive(:capture2e).and_return(['', OpenStruct.new(:exitstatus => 1)])

          expect{
            subject.print_gem_environment #('', '', '')
          }.to raise_error(ErrorWithLogDetails)
        end
      end
    end

    describe '#execute_specs' do
      let(:context) { double('context',
          path_environment: 'path environment', gems_folder: 'gems folder', bundle_command: 'command', working_dir: working_dir,
          cpi_release: release_archive_path, skip_cleanup?: 'TRUE', verbose?: 'TRUE', config: 'validator_config_path',
          validator_root_dir: expand_project_path(''), tag: nil, fail_fast?: false)
      }
      let(:env) do
        {
          'PATH' => context.path_environment,
          'GEM_PATH' => context.gems_folder,
          'GEM_HOME' => context.gems_folder,
          'BOSH_PACKAGES_DIR' => File.join(working_dir, 'packages'),
          'BOSH_OPENSTACK_CPI_LOG_PATH' => File.join(working_dir, 'logs'),
          'BOSH_OPENSTACK_STEMCELL_PATH' => File.join(working_dir, 'stemcell'),
          'BOSH_OPENSTACK_CPI_PATH' => File.join(working_dir, 'cpi'),
          'BOSH_OPENSTACK_VALIDATOR_CONFIG' => 'validator_config_path',
          'BOSH_OPENSTACK_CPI_CONFIG' => File.join(working_dir, 'cpi.json'),
          'BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP' => context.skip_cleanup?,
          'VERBOSE_FORMATTER' => context.verbose?,
          'http_proxy' => ENV['http_proxy'],
          'https_proxy' => ENV['https_proxy'],
          'no_proxy' => ENV['no_proxy'],
          'HOME' => ENV['HOME']
        }
      end
      let(:expected_command) {
        [
            "command exec rspec #{expand_project_path('src/specs')}",
            "--order defined",
            "--color --tty --require #{expand_project_path('lib/formatter.rb')}",
            "--format TestsuiteFormatter",
            "2> #{File.join(working_dir, 'logs', 'testsuite.log')}"
        ].join(" ")
      }

      it 'should execute specs' do
        allow(Open3).to receive(:popen3)

        subject.execute_specs

        expect(Open3).to have_received(:popen3).with(env, expected_command, unsetenv_others: true)
      end

      it 'should write the stdout to stdout' do
        allow(Open3).to receive(:popen3).and_yield('', ['we write stdout to stdout'], [''], OpenStruct.new(:value => 0))

        expect{
          subject.execute_specs
        }.to output("we write stdout to stdout\n").to_stdout
      end

      context 'when execution fails' do
        it 'raises an error' do
          allow(Open3).to receive(:popen3).and_yield('', [''], [''], OpenStruct.new(:value => 1))

          expect{
            subject.execute_specs
          }.to raise_error(ErrorWithLogDetails)
        end
      end

      context 'when option are set' do
        let(:context) { double('context',
            path_environment: 'path environment', gems_folder: 'gems folder', bundle_command: 'command', working_dir: working_dir,
            cpi_release: release_archive_path, skip_cleanup?: 'TRUE', verbose?: 'TRUE', config: 'validator_config_path',
            validator_root_dir: expand_project_path(''), tag: 'focus', fail_fast?: true)
        }
        let(:expected_command) {
          [
              "command exec rspec #{expand_project_path('src/specs')}",
              '--tag focus',
              '--fail-fast',
              '--order defined',
              "--color --tty --require #{expand_project_path('lib/formatter.rb')}",
              '--format TestsuiteFormatter',
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

    describe '#installation_exists?' do

      context 'should return false for non existing folder' do
        before(:each) { FileUtils.rm_r(working_dir) }

        it 'should return false' do
          expect(subject.installation_exists?).to eq(false)
        end
      end

      context 'should return false for empty folder' do
        it 'should return false' do
          expect(subject.installation_exists?).to eq(false)
        end
      end

      context 'when installation folder is not empty' do
        before(:each) do
          File.write(File.join(working_dir, 'dummy_installation'), '')
        end

        after(:each) do
          FileUtils.rm(File.join(working_dir, 'dummy_installation'))
        end

        it 'should return true' do
          expect(subject.installation_exists?).to eq(true)
        end
      end
    end

    describe '#check_installation?' do
      before(:each) do
        File.write(File.join(working_dir, '.completed'), release_archive_path)
      end

      after(:each) do
        File.delete(File.join(working_dir, '.completed')) if File.exist?(File.join(working_dir, '.completed'))
      end

      context 'when installation succeeded' do
        it 'return true without a message' do
          expect(subject.check_installation?).to eq([true, nil])
        end
      end

      context 'when the installation failed' do
        let(:expected_message) {
          "The CPI installation did not finish successfully.\n" +
          "Execute 'rm -rf #{working_dir}' and run the tests again."
        }
        it 'returns false with a message' do
          File.delete(File.join(working_dir, '.completed'))
          expect(subject.check_installation?).to eq([false, expected_message])
        end
      end

      context 'when the CPI version does not match' do
        let(:expected_message) {
          "Provided CPI and pre-installed CPI don't match.\n" +
              "Execute 'rm -rf #{working_dir}' and run the tests again."
        }
        it 'returns false with a message' do
          allow(context).to receive(:cpi_release).and_return('25')

          expect(subject.check_installation?).to eq([false, expected_message])
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

        expect(package_order).to eq([@a_dummy_package_path, @common_package_path, @second_dummy_package_path])
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