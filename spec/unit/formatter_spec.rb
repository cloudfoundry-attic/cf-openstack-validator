require 'rspec'
require 'formatter'

describe TestsuiteFormatter do

  subject {
    TestsuiteFormatter.new output
  }

  let(:output) {
    output = StringIO.new
  }

  describe '#dump_failures' do

    let(:notification) {
      instance_double(RSpec::Core::Notifications::ExamplesNotification)
    }

    context 'when no failure occured' do
      it 'should not print anything' do
        allow(notification).to receive(:failure_notifications).and_return([])

        subject.dump_failures(notification)

        expect(output.string).to be_empty
      end
    end

    context 'when there is a failure' do
      it 'should report only the error number, error description and the error message' do
        failure_notification = failure_notification('Failure description', 'Failure exception')

        allow(notification).to receive(:failure_notifications).and_return([failure_notification])

        subject.dump_failures(notification)

        expect(output.string).to eq("\nFailures:\n"\
                                    "\n" \
                                    "  0) Failure description\n" \
                                    "     Failure exception\n"
                                 )
      end
    end

    context 'when there are multiple failures' do
      it 'should report only the error number, error description and the error message' do
        failure_notification1 = failure_notification('Failure description1', 'Failure exception1')
        failure_notification2 = failure_notification('Failure description2', 'Failure exception2')
        allow(notification).to receive(:failure_notifications).and_return([failure_notification1, failure_notification2])

        subject.dump_failures(notification)

        expect(output.string).to eq("\nFailures:\n" \
                                    "\n" \
                                    "  0) Failure description1\n" \
                                    "     Failure exception1\n" \
                                    "\n" \
                                    "  1) Failure description2\n" \
                                    "     Failure exception2\n"
                                 )
      end
    end

    def failure_notification(description, exception_message)
      failure_notification = instance_double(RSpec::Core::Notifications::FailedExampleNotification)
      allow(failure_notification).to receive(:description).and_return(description)
      allow(failure_notification).to receive(:exception).and_return(Exception.new(exception_message))
      failure_notification
    end
  end

  describe '#dump_pending' do
    it 'should not produce output' do
      # Allow exactly ***no*** interaction with the notification object
      notification = instance_double(RSpec::Core::Notifications::ExamplesNotification)

      subject.dump_pending(notification)

      expect(output.string).to be_empty
    end
  end

  describe '#dump_summary' do
    it 'should report successful, pending and failing messages' do
      summary = instance_double(RSpec::Core::Notifications::SummaryNotification)
      allow(summary).to receive(:formatted_duration).and_return('47.11')
      allow(summary).to receive(:formatted_load_time).and_return('11.47')
      allow(summary).to receive(:colorized_totals_line).and_return('3 examples, 1 failures, 1 pending')

      subject.dump_summary(summary)

      expect(output.string).to eq("\nFinished in 47.11 (files took 11.47 to load)\n3 examples, 1 failures, 1 pending\n")
    end

  end
end