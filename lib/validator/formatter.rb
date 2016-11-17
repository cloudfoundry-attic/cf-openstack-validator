require 'rspec/core'
require 'pathname'
require_relative 'options'

module Validator
  class TestsuiteFormatter < RSpec::Core::Formatters::DocumentationFormatter
    RSpec::Core::Formatters.register self, :dump_failures, :dump_pending, :dump_summary,
      :example_started, :example_pending, :example_failed

    def initialize(output)
      super
      @env = Options.new(ENV)
    end

    def example_started(notification)
      output.print "#{current_indentation}#{notification.example.description}... "
    end

    def example_passed(notification)
      output.puts RSpec::Core::Formatters::ConsoleCodes.wrap("passed", :success)
    end

    def example_failed(notification)
      output.puts RSpec::Core::Formatters::ConsoleCodes.wrap("failed", :failure)
    end

    def example_pending(pending)
      pending_msg =  pending.example.execution_result.pending_message
      output.puts RSpec::Core::Formatters::ConsoleCodes.wrap("skipped: #{pending_msg}", :pending)
    end

    def dump_failures(notification)
      return if notification.failure_notifications.empty?
      formatted = "\nFailures:\n"
      notification.failure_notifications.each_with_index do |failure, index|
        formatted << formatted_failure(failure, index+1)
      end
      output.puts formatted
    end

    def dump_pending(notification)
    end

    def dump_summary(summary)
      output.puts "\nFinished in #{summary.formatted_duration} " \
                      "(files took #{summary.formatted_load_time} to load)\n" \
                      "#{summary.colorized_totals_line}\n"
      output.puts "Resources: #{RSpec.configuration.validator_resources.summary}"

      if summary.failure_count > 0
        output.puts "\nYou can find more information in the logs at #{File.join(Pathname.new(ENV['BOSH_OPENSTACK_CPI_LOG_PATH']).cleanpath, 'testsuite.log')}"
      end
    end

    private

    def formatted_failure(failure, failure_number, colorizer = ::RSpec::Core::Formatters::ConsoleCodes)
      if @env.verbose_output?
        failure.fully_formatted(failure_number, colorizer)
      else
        formatted = "\n  #{failure_number}) #{failure.description}\n"
        formatted << colorizer.wrap("     #{failure.exception.message}\n", RSpec.configuration.failure_color)
      end
    end
  end
end