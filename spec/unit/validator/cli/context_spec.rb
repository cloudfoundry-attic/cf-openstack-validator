require_relative '../../spec_helper'

module Validator::Cli
  describe Context do
    let(:options) { {} }
    let(:subject) { Context.new(options, working_directory) }
    let(:working_directory) { Dir.mktmpdir }

    after(:each) do
      if File.exists?(working_directory)
        FileUtils.rm_r(working_directory)
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
            Context.new(options, path)
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

    describe '#bundle_command' do
      it 'should return bundle command' do
        expect(subject.bundle_command).to eq("BUNDLE_GEMFILE=#{expand_project_path('Gemfile')} #{File.join(subject.working_dir, 'packages', 'ruby_openstack_cpi', 'bin', 'bundle')}")
      end
    end
  end
end