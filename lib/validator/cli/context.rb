module Validator::Cli
  class Context

    def initialize(options)
      @options = options
      @options[:working_dir] = ensure_working_directory(File.expand_path(@options[:working_dir]))
      @path_from_env = ENV['PATH']
    end


    def working_dir
      @options[:working_dir]
    end

    def tag
     @options[:tag]
    end

    def skip_cleanup?
      @options[:skip_cleanup]
    end

    def verbose?
      @options[:verbose]
    end

    def fail_fast?
      @options[:fail_fast]
    end

    def stemcell
      @options[:stemcell]
    end

    def cpi_release
      @options[:cpi_release]
    end

    def config
      @options[:config]
    end

    def validator_root_dir
      File.expand_path('../../../../', __FILE__)
    end

    def extracted_cpi_release_dir
      File.join(working_dir, File.basename(@options[:cpi_release], '.tgz'))
    end

    def path_environment
      cpi_executable_path = File.join(working_dir, 'packages', 'ruby_openstack_cpi', 'bin')
      "#{cpi_executable_path}:#{@path_from_env}"
    end

    def gems_folder
      File.join(working_dir, 'packages', 'ruby_openstack_cpi', 'lib', 'ruby', 'gems', '*')
    end

    def bundle_command
      "BUNDLE_GEMFILE=#{File.join(validator_root_dir, 'Gemfile')} #{File.join(working_dir, 'packages', 'ruby_openstack_cpi', 'bin', 'bundle')}"
    end

    private

    def ensure_working_directory(path)
      if path
        FileUtils.mkdir_p(path).first
      else
        Dir.mktmpdir
      end
    end
  end
end
