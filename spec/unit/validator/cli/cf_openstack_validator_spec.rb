require_relative '../../spec_helper'

module Validator::Cli
  describe CfOpenstackValidator do
    subject { CfOpenstackValidator.new({working_dir: tmp_path, cpi_release: release_archive_path}) }

    let(:release_archive_path) { expand_project_path('spec/assets/cpi-release.tgz') }

    before(:each) do
      FileUtils.mkdir_p(tmp_path)
    end

    after(:each) do
      if File.exists?(tmp_path)
        FileUtils.rm_r(tmp_path)
      end
    end

    describe '.create' do
      it 'ensures working directory exists' do
        tmp_dir = File.join(Dir.mktmpdir, 'cf-validator')

        CfOpenstackValidator.create({working_dir: tmp_dir})

        expect(File.directory?(tmp_dir)).to be(true)
      end
    end

    describe '.ensure_working_directory' do
      context 'when path is given' do
        context 'when path does not exist' do
          it 'creates a directory' do
            path = CfOpenstackValidator.ensure_working_directory(File.join(tmp_path, 'does_not_exist'))

            expect(File.directory?(path)).to be(true)
          end
        end

        context 'when path points to an existing file' do
          it 'raises an error' do
            path = File.join(tmp_path, 'file')
            FileUtils.touch(path)

            expect {
              CfOpenstackValidator.ensure_working_directory(path)
            }.to raise_error Errno::EEXIST
          end
        end

        context 'when path points to an existing directory' do
          it 'does not raise' do
            path = File.join(tmp_path, 'directory')
            FileUtils.mkdir_p(path)

            expect {
              CfOpenstackValidator.ensure_working_directory(path)
            }.to_not raise_error

            expect(File.directory?(path)).to be(true)
          end
        end
      end

      context 'when path is \'nil\'' do
        it 'creates a directory in OS tmp path' do
          path = CfOpenstackValidator.ensure_working_directory(nil)

          expect(File.directory?(path)).to be(true)
        end
      end
    end


    describe '#deep_extract_release' do
      it 'extracts the release and its packages' do
        subject.deep_extract_release(expand_project_path('spec/assets/cpi-release.tgz'))

        expect(File.exists?(File.join(tmp_path, 'cpi-release/packages/bosh_openstack_cpi/bosh_openstack_cpi/dummy_bosh_openstack_cpi'))).to be(true)
        expect(File.exists?(File.join(tmp_path, 'cpi-release/packages/ruby_openstack_cpi/ruby_openstack_cpi/dummy_ruby_openstack_cpi'))).to be(true)
      end
    end

    describe '#compile_package' do
      let(:package_path) { expand_project_path('spec/assets/cpi-release/packages/dummy_package') }

      it 'creates package folder' do
        subject.compile_package(package_path)

        expect(File.exists?(File.join(tmp_path, 'packages/dummy_package'))).to be(true)
      end

      it 'executes packaging script' do
        subject.compile_package(package_path)

        compiled_file_path = File.join(tmp_path, 'packages', 'compiled_file')
        expect(File.exists?(compiled_file_path)).to be(true)
        expect(File.read(compiled_file_path)).to eq("#{File.join(tmp_path, 'packages')}\n#{File.join(tmp_path, 'packages/dummy_package')}\n")
      end

      it 'writes log file' do
        subject.compile_package(package_path)

        logfile = File.join(tmp_path, 'logs', 'packaging-dummy_package.log')
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
        subject.install_cpi_release(release_archive_path)

        expect(File.exists?(File.join(tmp_path, 'cpi-release/packages/bosh_openstack_cpi/bosh_openstack_cpi/dummy_bosh_openstack_cpi'))).to be(true)
        expect(File.exists?(File.join(tmp_path, 'cpi-release/packages/ruby_openstack_cpi/ruby_openstack_cpi/dummy_ruby_openstack_cpi'))).to be(true)

        expect(File.exists?(File.join(tmp_path, 'packages', 'bosh_openstack_cpi'))).to be(true)
        expect(File.exists?(File.join(tmp_path, 'packages', 'ruby_openstack_cpi'))).to be(true)

        rendered_cpi_executable = File.join(tmp_path, 'cpi')
        expect(File.exists?(rendered_cpi_executable)).to be(true)
        expect(File.executable?(rendered_cpi_executable)).to be(true)
        expect(File.read(rendered_cpi_executable)).to eq <<EOF
#!/usr/bin/env bash

BOSH_PACKAGES_DIR=\${BOSH_PACKAGES_DIR:-#{File.join(tmp_path, 'packages')}}

PATH=\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin:\$PATH
export PATH

export BUNDLE_GEMFILE=\$BOSH_PACKAGES_DIR/bosh_openstack_cpi/Gemfile

bundle_cmd="\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin/bundle"
read -r INPUT
echo \$INPUT | \$bundle_cmd exec \$BOSH_PACKAGES_DIR/bosh_openstack_cpi/bin/openstack_cpi #{File.join(tmp_path, 'cpi.json')}
EOF
      end
    end

    describe '#extract_stemcell' do
      let(:stemcell_path) { expand_project_path('spec/assets/dummy.tgz') }

      it 'should extract the stemcell' do
        subject.extract_stemcell(stemcell_path)

        extracted_stemcell = File.join(tmp_path, 'stemcell')

        expect(File.directory?(extracted_stemcell)).to be(true)
        expect(Dir.glob(File.join(extracted_stemcell, '*'))).to_not be_empty
      end
    end

    describe '#prepare_ruby_environment' do

      let(:status) { OpenStruct.new(:exitstatus => 0) }
      let(:path_env_var) { '' }
      let(:gems_path) { '' }
      let(:bundle_command) { '' }
      let(:env) do
        {
            'BUNDLE_CACHE_PATH' => 'vendor/package',
            'PATH' => path_env_var,
            'GEM_PATH' => gems_path,
            'GEM_HOME' => gems_path
        }
      end

      it 'should execute bundle install' do
        allow(Open3).to receive(:capture2e).and_return(['', status])

        subject.prepare_ruby_environment(path_env_var, gems_path, bundle_command)

        expect(Open3).to have_received(:capture2e).with(env, "#{bundle_command} install --local")
      end

      it 'should write log to `bundle_install.log` file' do
        allow(Open3).to receive(:capture2e).and_return(['bundle log', status])

        subject.prepare_ruby_environment(path_env_var, gems_path, bundle_command)

        logfile = File.join(tmp_path, 'logs', 'bundle_install.log')
        expect(File.exists?(logfile)).to be(true)
        expect(File.read(logfile)).to eq('bundle log')
      end

      context 'when `bundle install` fails' do
        let(:status) { OpenStruct.new(:exitstatus => 1) }

        it 'raises an error with log details' do
          allow(Open3).to receive(:capture2e).and_return(['error', status])

          expect {
            subject.prepare_ruby_environment(path_env_var, gems_path, bundle_command)
          }.to raise_error(ErrorWithLogDetails)
        end
      end
    end

    describe '#path_environment' do
      it 'should return path environment' do
        expect(subject.path_environment).to eq("#{File.join(tmp_path, 'packages', 'ruby_openstack_cpi', 'bin')}:#{ENV['PATH']}")
      end
    end

    describe '#gems_folder' do
      it 'should return gems folder path' do
        expect(subject.gems_folder).to eq(File.join(tmp_path, 'packages', 'ruby_openstack_cpi', 'lib', 'ruby', 'gems', '*'))
      end
    end

    describe '#bundle_command' do
      it 'should return bundle command' do
        expect(subject.bundle_command).to eq("BUNDLE_GEMFILE=#{expand_project_path('Gemfile')} #{File.join(tmp_path, 'packages', 'ruby_openstack_cpi', 'bin', 'bundle')}")
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
          subject.generate_cpi_config(validator_config_path)
        }.to output(/CPI will use the following configuration/).to_stdout

        expect(File.exist?(File.join(tmp_path, 'cpi.json'))).to eq(true)
        expect(Converter).to have_received(:to_cpi_json).with(CfValidator.configuration.openstack)
      end

      context 'when config is invalid' do
        let(:validator_config_path) { Tempfile.new('validator.yml').path }

        after(:each) {File.delete(validator_config_path)}

        it 'should abort generation' do
          expect {
            subject.generate_cpi_config(validator_config_path)
          }.to raise_error(RuntimeError)
        end
      end
    end

    describe '#print_gem_environment' do
      it 'should print the gem environment and list of all gems' do
        bundle_command = 'command'
        path_environment = 'path environment'
        gems_folder = 'gems folder'
        env = {
            'PATH' => path_environment,
            'GEM_PATH' => gems_folder,
            'GEM_HOME' => gems_folder
        }
        gems_log_content = "it prints gems environment\nGems included by the bundle:"
        allow(Open3).to receive(:capture2e).and_return([gems_log_content, OpenStruct.new(:exitstatus => 0)])


        subject.print_gem_environment(path_environment, gems_folder, bundle_command)

        expect(Open3).to have_received(:capture2e).with(env, 'command exec gem environment && command list')
        expect(File.exist?(File.join(tmp_path, 'logs', 'gem_environment.log'))).to eq(true)
        expect(File.read(File.join(tmp_path, 'logs', 'gem_environment.log'))).to eq(gems_log_content)
      end

      context 'when print fails' do
        it 'should raise exception' do
          allow(Open3).to receive(:capture2e).and_return(['', OpenStruct.new(:exitstatus => 1)])

          expect{
            subject.print_gem_environment('', '', '')
          }.to raise_error(ErrorWithLogDetails)
        end
      end
    end

    describe '#execute_specs' do
      let(:bundle_command) { 'command' }
      let(:path_environment) { 'path environment' }
      let(:gems_folder) { 'gems folder' }
      let(:env) do
        {
          'PATH' => path_environment,
          'GEM_PATH' => gems_folder,
          'GEM_HOME' => gems_folder,
          'BOSH_PACKAGES_DIR' => File.join(tmp_path, 'packages'),
          'BOSH_OPENSTACK_CPI_LOG_PATH' => File.join(tmp_path, 'logs'),
          'BOSH_OPENSTACK_STEMCELL_PATH' => File.join(tmp_path, 'stemcell'),
          'BOSH_OPENSTACK_CPI_PATH' => File.join(tmp_path, 'cpi'),
          'BOSH_OPENSTACK_VALIDATOR_CONFIG' => 'validator_config_path',
          'BOSH_OPENSTACK_CPI_CONFIG' => File.join(tmp_path, 'cpi.json'),
          'BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP' => ENV['BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP'],
          'VERBOSE_FORMATTER' => ENV['VERBOSE_FORMATTER'],
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
            "--color --require #{expand_project_path('lib/formatter.rb')}",
            "--format TestsuiteFormatter"
        ].join(" ")
      }

      it 'should execute specs' do
        allow(Open3).to receive(:popen2e)

        subject.execute_specs('validator_config_path', path_environment, gems_folder, bundle_command)

        expect(Open3).to have_received(:popen2e).with(env, expected_command)
      end

      it 'should write the stderr to the log' do
        allow(Open3).to receive(:popen2e).and_yield([''], ['we write only stderr'], OpenStruct.new(:value => 0))

        subject.execute_specs('validator_config_path', path_environment, gems_folder, bundle_command)

        expect(File.exist?(File.join(tmp_path, 'logs', 'testsuite.log'))).to eq(true)
        expect(File.read(File.join(tmp_path, 'logs', 'testsuite.log'))).to eq('we write only stderr')
      end

      it 'should write the stdout to stdout' do
        allow(Open3).to receive(:popen2e).and_yield(['we write stdout to stdout'], [''], OpenStruct.new(:value => 0))

        expect{
          subject.execute_specs('validator_config_path', path_environment, gems_folder, bundle_command)
        }.to output("we write stdout to stdout\n").to_stdout
      end

      context 'when execution fails' do
        it 'should write the stdout to stdout' do
          allow(Open3).to receive(:popen2e).and_yield([''], ['we write only stderr'], OpenStruct.new(:value => 1))

          expect{
            subject.execute_specs('validator_config_path', path_environment, gems_folder, bundle_command)
          }.to raise_error(ErrorWithLogDetails)
        end
      end

      context 'when option are set' do
        let(:expected_command) {
          [
              "command exec rspec #{expand_project_path('src/specs')}",
              '--tag focus',
              '--fail-fast',
              '--order defined',
              "--color --require #{expand_project_path('lib/formatter.rb')}",
              '--format TestsuiteFormatter'
          ].join(' ')
        }
        it 'should execute specs with fail fast option' do
          ENV['FAIL_FAST'] = 'true'
          ENV['TAG'] = 'focus'
          allow(Open3).to receive(:popen2e)

          subject.execute_specs('validator_config_path', path_environment, gems_folder, bundle_command)

          expect(Open3).to have_received(:popen2e).with(env, expected_command)
        end
      end
    end
  end
end