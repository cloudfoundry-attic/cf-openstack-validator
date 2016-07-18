require_relative 'spec_helper'

describe Cli do
  subject { Cli.new(env) }

  context 'ENV["BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP"]' do
    context 'is not set' do
      let(:env) { {} }

      it 'skip cleanup returns false' do
        expect(subject.skip_cleanup?).to be(false)
      end
    end

    context 'is set to "true"' do
      let(:env) { { "BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP" => 'true'} }

      it 'skip cleanup returns true' do
        expect(subject.skip_cleanup?).to be(true)
      end
    end

    context 'is set to "TRUE"' do
      let(:env) { { "BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP" => 'TRUE'} }

      it 'skip cleanup returns true' do
        expect(subject.skip_cleanup?).to be(true)
      end
    end

    context 'is set to "false"' do
      let(:env) { { "BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP" => 'false'} }

      it 'skip cleanup returns false' do
        expect(subject.skip_cleanup?).to be(false)
      end
    end

    context 'is set to anything else' do
      let(:env) { { "BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP" => 'foobar'} }

      it 'skip cleanup returns false' do
        expect(subject.skip_cleanup?).to be(false)
      end
    end
  end
end
