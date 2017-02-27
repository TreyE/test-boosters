module Semaphore
  require "json"
  require "test_boosters/cli_parser"
  require "test_boosters/logger"
  require "test_boosters/executor"
  require "test_boosters/display_files"
  require "test_boosters/leftover_files"

  class RspecBooster
    def initialize(thread_index)
      @thread_index = thread_index
      @report_path = ENV["REPORT_PATH"] || "#{ENV["HOME"]}/rspec_report.json"
      @spec_path = ENV["SPEC_PATH"] || "spec"
    end

    def run
      begin
        specs_to_run = select

        if specs_to_run.empty?
            puts "No spec files in this thread!"
        else
          run_command(specs_to_run.join(" "))
        end
      rescue StandardError => e
        if @thread_index == 0
          run_command(@spec_path)
        end
      end
    end

    def run_command(specs)
      options = "--format documentation --format json --out #{@report_path}"
      puts "options: #{options}"
      Semaphore::execute("bundle exec rspec #{options} #{specs}")
    end

    def select
      with_fallback do
        rspec_report = JSON.parse(File.read(@report_path))
        thread_count = rspec_report.count
        thread = rspec_report[@thread_index]

        all_specs = Dir["#{@spec_path}/**/*_spec.rb"].sort
        all_known_specs = rspec_report.map { |t| t["files"] }.flatten.sort

        all_leftover_specs = all_specs - all_known_specs
        thread_leftover_specs = LeftoverFiles::select(all_leftover_specs, thread_count, @thread_index)
        thread_specs = all_specs & thread["files"].sort
        specs_to_run = thread_specs + thread_leftover_specs

        Semaphore::display_files("This thread specs:", thread_specs)
        Semaphore::display_title_and_count("All leftover specs:", all_leftover_specs)
        Semaphore::display_files("This thread leftover specs:", thread_leftover_specs)

        specs_to_run
      end
    end


    def with_fallback
      yield
    rescue StandardError => e
      error = %{
        WARNING: An error detected while parsing the test boosters report file.
        WARNING: All tests will be executed on the first thread.
      }

      puts error

      error += %{Exception: #{e.message}}

      Semaphore::log(error)

      raise
    end

  end
end
