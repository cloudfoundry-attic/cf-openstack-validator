require_relative '../../spec_helper'
require 'securerandom'

module Validator::Cli
  describe Context do
    let(:working_directory) { Dir.mktmpdir }
    let(:default_options) {
      {working_dir: working_directory}
    }
    let(:cli_options) { {} }
    let(:subject) {
      Context.new(cli_options.merge(default_options))
    }

    after(:each) do
      if File.exists?(working_directory)
        FileUtils.rm_r(working_directory)
      end
    end

    describe '#cpi_bin_path' do
      it 'sets the default' do
        expect(subject.cpi_bin_path).to eq(File.join(subject.working_dir, 'cpi'))
      end
    end

    describe :openstack_cpi_bin_from_env do
      context 'when ENV var is set' do
        before do
          ENV['OPENSTACK_CPI_BIN'] = 'some-path'
        end

        after do
          ENV.delete('OPENSTACK_CPI_BIN')
        end

        it 'returns the value of OPENSTACK_CPI_BIN environment variable' do
          expect(subject.openstack_cpi_bin_from_env).to eq('some-path')
        end
      end

      context 'when ENV var is not set' do
        it 'returns nil' do
          expect(subject.openstack_cpi_bin_from_env).to be(nil)
        end
      end

    end

    describe :working_dir do
      context 'when path does not exist' do
        it 'creates a directory' do
          path = subject.working_dir

          expect(File.directory?(path)).to be(true)
        end
      end

      context 'when path points to an existing file' do
        it 'raises an error' do
          path = File.join(working_directory, '.cf-openstack-validator')
          FileUtils.touch(path)

          expect {
            Context.new(cli_options.merge({working_dir: path}))
          }.to raise_error Errno::EEXIST
        end
      end

      context 'when path points to an existing directory' do
        it 'does not raise' do
          path = File.join(working_directory, '.cf-openstack-validator')
          FileUtils.mkdir_p(path)
          expect {
            subject.working_dir
          }.to_not raise_error

          expect(File.directory?(path)).to be(true)
        end
        context 'when path is a relative path' do
          let(:working_directory) {
            "relative-working-directory-#{SecureRandom.uuid}"
          }

          before(:each) {
            FileUtils.mkdir_p(working_directory)
          }
          it 'is updated to an absolute path' do
            expect(subject.working_dir).to start_with('/')
            expect(subject.working_dir).to include(working_directory)
          end
        end
      end
    end

    describe '#path_environment' do
      it 'should return path environment' do
        expect(subject.path_environment).to eq("#{File.join(subject.working_dir, 'packages', 'ruby_openstack_cpi', 'bin')}:#{ENV['PATH']}")
      end
    end

    describe '#gems_folder' do
      it 'should return gems folder path' do
        expect(subject.gems_folder).to eq(File.join(subject.working_dir, 'packages', 'ruby_openstack_cpi', 'lib', 'ruby', 'gems', '*'))
      end
    end

    describe '#packages_path' do
      it 'should return gems folder path' do
        expect(subject.packages_path).to eq(File.join(subject.working_dir, 'packages'))
      end
    end

    describe '#create_validator_options' do
      let(:cli_options) do
        {
            config_path: 'validator_config_path',
            skip_cleanup: true,
            verbose: true
        }
      end

      it 'sets all options' do
        expected_options = Validator::Cli::Options.new(
          File.join(working_directory, 'packages'),
          File.join(working_directory, 'logs'),
          File.join(working_directory, 'stemcell'),
          File.join(working_directory, 'cpi'),
          'validator_config_path',
          File.join(working_directory, 'jobs/openstack_cpi/config/cpi.json'),
          true,
          true
        )

        expect(subject.create_validator_options).to eq(expected_options)
      end

      it 'returns a frozen Option instance' do
        expect(subject.create_validator_options.frozen?).to eq(true)
      end
    end
  end
end
