require_relative 'spec_helper'
require 'fileutils'

describe Extensions do

  before(:each) do
    @tmpdir = Dir.mktmpdir
    @validator_config = File.join(@tmpdir, 'validator.yml')
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

    context 'when extension folder is used' do

      before(:each) do
        @extensionsdir = File.join(@tmpdir, 'extensions')
        FileUtils.mkdir(@extensionsdir)
      end

      context 'and contains no _spec.rb files' do
        it 'returns no specs' do
          expect(Extensions.all.size).to eq(0)
        end
      end

      context 'and contains multiple _spec.rb files' do
        before do
          FileUtils.touch(File.join(@extensionsdir, 'test1_spec.rb'))
          FileUtils.touch(File.join(@extensionsdir, 'test2_spec.rb'))
        end

        it 'returns all specs' do
          specs = Extensions.all
          expect(specs.size).to eq(2)
          expect(specs).to eq(["#{@extensionsdir}/test1_spec.rb", "#{@extensionsdir}/test2_spec.rb"])
        end

        context 'and also contains non-spec files' do
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
    end

    context 'when default extension folder does not exist' do
      it 'returns no specs' do
        specs = Extensions.all
        expect(specs.size).to eq(0)
      end
    end

    context 'when there is a `extensions` section in the `validator.yml`' do

      context 'and an extension directory is specified in the config file' do

        before(:each) do
          cf_openstack_validator = File.join(@tmpdir, 'cf-openstack-validator')
          FileUtils.mkdir(cf_openstack_validator)
          validator_config = File.join(cf_openstack_validator, 'validator.yml')

          File.write(validator_config, validator_config_content)
          ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'] = validator_config
        end

        context 'and the path is absolute' do
          let(:absolute_path_to_extensions) { Dir.mktmpdir }
          let(:validator_config_content) do
            <<-EOF
extensions:
  paths: [#{absolute_path_to_extensions}]
            EOF
          end

          before(:each) do
            @non_default_spec = File.join(absolute_path_to_extensions, 'my_spec.rb')
            FileUtils.touch(@non_default_spec)
          end

          it 'returns all specs' do
            specs = Extensions.all
            expect(specs.size).to eq(1)
            expect(specs).to eq([@non_default_spec])
          end

          after(:each) do
            FileUtils.rmtree(absolute_path_to_extensions)
          end
        end

        context 'and the path is relative to the config file' do
          let(:validator_config_content) do
            <<-EOF
extensions:
  paths: [../my-extensions]
            EOF
          end

          before(:each) do
            my_extensions = File.join(@tmpdir, 'my-extensions')
            FileUtils.mkdir(my_extensions)
            @non_default_spec = File.join(my_extensions, 'my_spec.rb')
            FileUtils.touch(@non_default_spec)
          end

          it 'returns all specs' do
            specs = Extensions.all
            expect(specs.size).to eq(1)
            expect(specs).to eq([@non_default_spec])
          end

          after(:each) do
            FileUtils.rmtree(File.join(@tmpdir, 'my-extensions'))
          end
        end

      end

      context 'when the extension path is invalid' do
        let(:validator_config_content) {
          <<-EOF
extensions:
  paths: [./non-existent]
          EOF
        }

        before(:each) do
          File.write(@validator_config, validator_config_content)
        end

        it 'raises an StandardError' do
          expect{ Extensions.all }.to raise_error(StandardError, /\/non-existent' is not a directory./)
        end
      end

    end
  end

  describe '.eval' do
    before do
      @extensionsdir = File.join(@tmpdir, 'extensions')
      FileUtils.mkdir(@extensionsdir)
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

    context 'when extension evaluation raises an exception' do
      before do
        File.write(File.join(@extensionsdir, 'a_syntax_error_spec.rb'), '%fa#23')
        @specs <<  File.join(@extensionsdir, 'a_syntax_error_spec.rb')
      end

      it 'returns an error object' do
        allow($stdout).to receive(:puts)
        expect{Extensions.eval(@specs, binding)}.to raise_error(SyntaxError)
      end

      it 'prints to the error to stdout' do
        expect{
          begin
            Extensions.eval(@specs, binding)
          rescue SyntaxError
            # not relevant for test
          end
        }.to output(/unknown type of %string\n%fa#23\n /).to_stdout
      end

      context 'VERBOSE_FORMATTER' do
        before(:each) do
          @orig = ENV['VERBOSE_FORMATTER']
        end

        after(:each) do
          if @orig
            ENV['VERBOSE_FORMATTER'] = @orig
          else
            ENV.delete('VERBOSE_FORMATTER')
          end
        end

        context 'when VERBOSE_FORMATTER=true is given' do
          before(:each) do
            ENV['VERBOSE_FORMATTER'] = 'true'
          end

          it 'prints the errors backtrace to stdout' do
            expect{
              begin
                Extensions.eval(@specs, binding)
              rescue SyntaxError
                # not relevant for test
              end
            }.to output(/:in `eval'/).to_stdout
          end
        end

        context 'VERBOSE_FORMATTER not true' do
          before(:each) do
            ENV['VERBOSE_FORMATTER'] = 'anything but true'
          end

          it 'prints the errors without backtrace to stdout' do
            expect{
              begin
                Extensions.eval(@specs, binding)
              rescue SyntaxError
                # not relevant for test
              end
            }.not_to output(/:in `eval'/).to_stdout
          end
        end
        end
      end
  end
end