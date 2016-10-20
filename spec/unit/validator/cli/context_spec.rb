require_relative '../../spec_helper'

module Validator::Cli
  describe Context do
    let(:options) { { working_dir: File.join(Dir.mktmpdir) } }
    let(:subject) { Context.new(options) }

    after(:each) do
      if File.exists?(options[:working_dir])
        FileUtils.rm_r(options[:working_dir])
      end
    end

    describe :working_dir do
      context 'when path is given' do

        context 'when path does not exist' do
          let(:options) { { working_dir: File.join(Dir.mktmpdir, 'not_existent') } }

          it 'creates a directory' do
            path = subject.working_dir

            expect(File.directory?(path)).to be(true)
          end
        end

        context 'when path points to an existing file' do
          let(:options) do
            path = File.join(Dir.mktmpdir, 'file')
            FileUtils.touch(path)
            { working_dir: path }
          end

          it 'raises an error' do

            expect {
              Context.new(options)
            }.to raise_error Errno::EEXIST
          end
        end

        context 'when path points to an existing directory' do
          let(:options) { { working_dir: Dir.mktmpdir } }
          it 'does not raise' do
            path = File.join(options[:working_dir], 'directory')
            FileUtils.mkdir_p(path)

            expect {
              subject.working_dir
            }.to_not raise_error

            expect(File.directory?(path)).to be(true)
          end
        end

        context 'when path is relative' do
          let(:options) { { working_dir: 'some-tmp-dir' } }
          it 'returns the corresponding absolute path' do
            expect(subject.working_dir).to eq(File.expand_path('some-tmp-dir'))
          end
        end
      end

      context 'when path is nil' do
        let(:options) { { working_dir: nil } }
        it 'creates a directory in OS tmp path' do
          path = subject.working_dir

          expect(File.directory?(path)).to be(true)
        end
      end
    end

    describe '#path_environment' do
      it 'should return path environment' do
        expect(subject.path_environment).to eq("#{File.join(options[:working_dir], 'packages', 'ruby_openstack_cpi', 'bin')}:#{ENV['PATH']}")
      end
    end

    describe '#gems_folder' do
      it 'should return gems folder path' do
        expect(subject.gems_folder).to eq(File.join(options[:working_dir], 'packages', 'ruby_openstack_cpi', 'lib', 'ruby', 'gems', '*'))
      end
    end

    describe '#bundle_command' do
      it 'should return bundle command' do
        expect(subject.bundle_command).to eq("BUNDLE_GEMFILE=#{expand_project_path('Gemfile')} #{File.join(options[:working_dir], 'packages', 'ruby_openstack_cpi', 'bin', 'bundle')}")
      end
    end
  end
end