require_relative 'spec_helper'

describe TestsuiteFormatter do

  subject {
    TestsuiteFormatter.new output
  }

  let(:output) {
    output = StringIO.new
  }

  before do
    ENV['VERBOSE_FORMATTER'] = 'false'
  end

  describe '#dump_failures' do

    let(:notification) {
      instance_double(RSpec::Core::Notifications::ExamplesNotification)
    }

    context 'when no failure occurred' do
      it 'should not print anything' do
        allow(notification).to receive(:failure_notifications).and_return([])

        subject.dump_failures(notification)

        expect(output.string).to be_empty
      end
    end

    context 'when there is a failure' do
      let(:failure_notification) { mock_failure_notification('Failure description', 'Failure exception') }

      it 'should report only the error number, error description and the error message' do
        allow(notification).to receive(:failure_notifications).and_return([failure_notification])

        subject.dump_failures(notification)

        expect(output.string).to eq("\nFailures:\n"\
                                    "\n" \
                                    "  1) Failure description\n" \
                                    "     Failure exception\n"
                                 )
      end

      context 'and VERBOSE_FORMATTER is used' do
        before do
          ENV['VERBOSE_FORMATTER'] = 'true'
        end

        let(:failure_notification) { instance_double(RSpec::Core::Notifications::FailedExampleNotification) }

        it 'should report full stacktrace' do
          expect(failure_notification).to receive(:fully_formatted).and_return('some backtrace')
          allow(notification).to receive(:failure_notifications).and_return([failure_notification])

          subject.dump_failures(notification)

          expect(output.string).to eq("\nFailures:\n"\
                                    "some backtrace\n"
                                   )
        end
      end
    end

    context 'when there are multiple failures' do
      let(:failure_notification1) { mock_failure_notification('Failure description1', 'Failure exception1') }
      let(:failure_notification2) { mock_failure_notification('Failure description2', 'Failure exception2') }

      it 'should report only the error number, error description and the error message' do
        allow(notification).to receive(:failure_notifications).and_return([failure_notification1, failure_notification2])

        subject.dump_failures(notification)

        expect(output.string).to eq("\nFailures:\n" \
                                    "\n" \
                                    "  1) Failure description1\n" \
                                    "     Failure exception1\n" \
                                    "\n" \
                                    "  2) Failure description2\n" \
                                    "     Failure exception2\n"
                                 )
      end

      context 'and VERBOSE_FORMATTER is used' do
        before do
          ENV['VERBOSE_FORMATTER'] = 'true'
        end

        let(:failure_notification1) { instance_double(RSpec::Core::Notifications::FailedExampleNotification) }
        let(:failure_notification2) { instance_double(RSpec::Core::Notifications::FailedExampleNotification) }

        it 'should report full stacktrace' do
          expect(failure_notification1).to receive(:fully_formatted).and_return("some backtrace\n")
          expect(failure_notification2).to receive(:fully_formatted).and_return("some other backtrace\n")
          allow(notification).to receive(:failure_notifications).and_return([failure_notification1, failure_notification2])

          subject.dump_failures(notification)

          expect(output.string).to eq("\nFailures:\n"\
                                    "some backtrace\n"\
                                    "some other backtrace\n"
                                   )
        end
      end
    end

    def mock_failure_notification(description, exception_message)
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

    let(:failure_count) { 0 }
    let(:summary) { instance_double(RSpec::Core::Notifications::SummaryNotification) }
    let(:resource_tracker) { instance_double(ResourceTracker) }

    before(:each) do
      allow(summary).to receive(:formatted_duration).and_return('47.11')
      allow(summary).to receive(:formatted_load_time).and_return('11.47')
      allow(summary).to receive(:failure_count).and_return(failure_count)
      allow(summary).to receive(:colorized_totals_line).and_return('3 examples, 1 failures, 1 pending')
    end

    it 'should report successful, pending and failing messages' do
      subject.dump_summary(summary)

      expect(output.string).to include("\nFinished in 47.11 (files took 11.47 to load)\n3 examples, 1 failures, 1 pending\n")
    end

    it 'gets the summary from the resource tracker' do
      allow(resource_tracker).to receive(:summary).and_return('resources-summary')
      allow(CfValidator).to receive(:resources).and_return(resource_tracker)

      subject.dump_summary(summary)

      expect(output.string).to include('resources-summary')
    end

    context 'with test failures' do

      let(:failure_count) { 1 }

      before(:each) do
        @orig_log_path = ENV['BOSH_OPENSTACK_CPI_LOG_PATH']
        ENV['BOSH_OPENSTACK_CPI_LOG_PATH'] = 'test/path'
      end

      after(:each) do
        ENV['BOSH_OPENSTACK_CPI_LOG_PATH'] = @orig_log_path if @orig_log_path
      end

      it 'points the user to the log file' do
        subject.dump_summary(summary)

        expect(output.string).to match(/You can find more information in the logs at test\/path\/testsuite.log/)
      end
    end
  end
end