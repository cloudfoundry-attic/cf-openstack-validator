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
  end
end