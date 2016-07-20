require_relative 'spec_helper'

describe Cli do
  subject { Cli.new(env) }

  describe '#skip_cleanup?' do
    context 'when ENV["BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP"]' do
      context 'is not set' do
        let(:env) { {} }

        it 'returns false' do
          expect(subject.skip_cleanup?).to be(false)
        end
      end

      context 'is set to "true"' do
        let(:env) { { 'BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP' => 'true' } }

        it 'returns true' do
          expect(subject.skip_cleanup?).to be(true)
        end
      end

      context 'is set to "TRUE"' do
        let(:env) { { 'BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP' => 'TRUE' } }

        it 'returns true' do
          expect(subject.skip_cleanup?).to be(true)
        end
      end

      context 'is set to "false"' do
        let(:env) { { 'BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP' => 'false' } }

        it 'returns false' do
          expect(subject.skip_cleanup?).to be(false)
        end
      end

      context 'is set to anything else' do
        let(:env) { { 'BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP' => 'foobar' } }

        it 'returns false' do
          expect(subject.skip_cleanup?).to be(false)
        end
      end
    end
  end
  describe '#verbose_output?' do
    context 'when ENV["VERBOSE_FORMATTER"]' do
      context 'is not set' do
        let(:env) { {} }

        it 'returns false' do
          expect(subject.verbose_output?).to be(false)
        end
      end

      context 'is set to "true"' do
        let(:env) { { 'VERBOSE_FORMATTER' => 'true' } }

        it 'returns true' do
          expect(subject.verbose_output?).to be(true)
        end
      end

      context 'is set to "TRUE"' do
        let(:env) { { 'VERBOSE_FORMATTER' => 'TRUE' } }

        it 'returns true' do
          expect(subject.verbose_output?).to be(true)
        end
      end

      context 'is set to "false"' do
        let(:env) { { 'VERBOSE_FORMATTER' => 'false' } }

        it 'returns false' do
          expect(subject.verbose_output?).to be(false)
        end
      end

      context 'is set to anything else' do
        let(:env) { { 'VERBOSE_FORMATTER' => 'foobar' } }

        it 'returns false' do
          expect(subject.verbose_output?).to be(false)
        end
      end
    end
  end
end
