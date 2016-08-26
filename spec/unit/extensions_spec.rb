require_relative 'spec_helper'
require 'fileutils'

describe Extensions do

  before(:each) do
    @tmpdir = Dir.mktmpdir
    @validator_config = File.join(@tmpdir, 'validator.yml')
    @extensionsdir = File.join(@tmpdir, 'extensions')
    FileUtils.mkdir(@extensionsdir)
    ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'] = @validator_config
  end

  after(:each) do
    ENV.delete('BOSH_OPENSTACK_VALIDATOR_CONFIG')
    FileUtils.rm_rf(@tmpdir)
  end

  describe '.all' do
    before(:each) do
      File.write(@validator_config, '---')
    end

    context 'extensions folder contains no _spec.rb files' do
      it 'returns no specs' do
        expect(Extensions.all.size).to eq(0)
      end
    end

    context 'extensions folder contains multiple _spec.rb files' do
      before do
        FileUtils.touch(File.join(@extensionsdir, 'test1_spec.rb'))
        FileUtils.touch(File.join(@extensionsdir, 'test2_spec.rb'))
      end

      it 'returns all specs' do
        specs = Extensions.all
        expect(specs.size).to eq(2)
        expect(specs).to eq(["#{@extensionsdir}/test1_spec.rb", "#{@extensionsdir}/test2_spec.rb"])
      end

      context 'extensions folder also contains non-spec files' do
        before do
          FileUtils.touch(File.join(@extensionsdir, 'some-file'))
        end

        it 'returns only the spec files' do
          specs = Extensions.all
          expect(specs.size).to equal(2)
          expect(specs).to eq(["#{@extensionsdir}/test1_spec.rb", "#{@extensionsdir}/test2_spec.rb"])
        end
      end
    end

    context 'when there is a `extensions` section in the `validator.yml`' do

      context 'when an extension path specifies a spec file' do
        let(:validator_config_content) do
          <<-EOF
extensions:
- name: extension1
  path: ./custom_extensions/my_spec.rb
          EOF
        end

        before(:each) do
          File.write(@validator_config, validator_config_content)
          extensions_dir = File.join(@tmpdir, 'custom_extensions')
          FileUtils.mkdir(extensions_dir)
          @my_spec = File.join(extensions_dir, 'my_spec.rb')
          FileUtils.touch(@my_spec)
        end

        it 'supports file and dir paths' do
          expect(Extensions.all.size).to eq(1)
          expect(Extensions.all).to eq( [File.join(@tmpdir,'/custom_extensions/my_spec.rb')] )
        end

      end

      context 'when different extensions are specified in the config file' do

        let(:validator_config_content) do
          <<-EOF
extensions:
- name: extension1
  path: #{Dir.mktmpdir}
- name: extension2
  path: ../my-extensions
          EOF
        end

        before(:each) do
          cf_openstack_validator = File.join(@tmpdir, 'cf-openstack-validator')
          FileUtils.mkdir(cf_openstack_validator)
          validator_config = File.join(cf_openstack_validator, 'validator.yml')

          File.write(validator_config, validator_config_content)
          ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'] = validator_config

          my_extensions = File.join(@tmpdir, 'my-extensions')
          FileUtils.mkdir(my_extensions)
          @my_spec = File.join(my_extensions, 'my_spec.rb')
          FileUtils.touch(@my_spec)
        end

        it 'returns all specs' do
          specs = Extensions.all
          expect(specs.size).to eq(1)
          expect(specs).to eq([@my_spec])
        end

      end

      context 'when an extension specifies an invalid path' do
        let(:validator_config_content) {
          <<-EOF
extensions:
- name: extension1
  path: ./non-existent
          EOF
        }

        before(:each) do
          File.write(@validator_config, validator_config_content)
        end

        it 'raises an StandardError' do
          expect{ Extensions.all }.to raise_error(StandardError, /\/non-existent' does not exist/)
        end
      end

      context 'when multiple entries resolve to the same paths' do
        let(:validator_config_content) {
          <<-EOF
extensions:
- name: extension1
  path: ./custom_extensions/my_spec.rb
- name: extension2
  path: ./custom_extensions/
          EOF
        }

        before(:each) do
          File.write(@validator_config, validator_config_content)
          extensions_dir = File.join(@tmpdir, 'custom_extensions')
          FileUtils.mkdir(extensions_dir)
          @my_spec = File.join(extensions_dir, 'my_spec.rb')
          FileUtils.touch(@my_spec)
        end

        it 'only take the path once' do
          expect(Extensions.all.size).to eq(1)
        end
      end

    end
  end

  describe '.eval' do
    before do
      @specs = [
          File.join(@extensionsdir, 'test1_spec.rb'),
          File.join(@extensionsdir, 'test2_spec.rb')
      ]

      @specs.each { |spec| FileUtils.touch(spec) }

      File.write(@validator_config, '---')
    end

    it 'tells which extension it is running' do
      expect{Extensions.eval(@specs, binding)}.to output("Evaluating extension: #{@extensionsdir}/test1_spec.rb\nEvaluating extension: #{@extensionsdir}/test2_spec.rb\n").to_stdout
    end
  end
end