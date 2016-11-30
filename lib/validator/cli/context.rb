module Validator::Cli
  class Context

    attr_reader :openstack_cpi_bin_from_env, :working_dir, :config

    attr_accessor :cpi_bin_path, :cpi_release_path

    def initialize(options, working_dir = "#{ENV['HOME']}/.cf-openstack-validator")
      @options = options
      @cpi_release_path = @options[:cpi_release]
      @working_dir = working_dir
      ensure_working_directory(@working_dir)
      @path_from_env = ENV['PATH']
      @openstack_cpi_bin_from_env = ENV['OPENSTACK_CPI_BIN']
      @cpi_bin_path = File.join(@working_dir, 'cpi')
      @config = Validator::Api::Configuration.new(config_path)
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

    def config_path
      @options[:config_path]
    end

    def validator_root_dir
      File.expand_path('../../../../', __FILE__)
    end

    def extracted_cpi_release_dir
      File.join(working_dir, 'cpi-release')
    end

    def path_environment
      cpi_executable_path = File.join(working_dir, 'packages', 'ruby_openstack_cpi', 'bin')
      "#{cpi_executable_path}:#{@path_from_env}"
    end

    def gems_folder
      File.join(working_dir, 'packages', 'ruby_openstack_cpi', 'lib', 'ruby', 'gems', '*')
    end

    def packages_path
      File.join(working_dir, 'packages')
    end

    def bundle_command
      "BUNDLE_GEMFILE=#{File.join(validator_root_dir, 'Gemfile')} #{File.join(working_dir, 'packages', 'ruby_openstack_cpi', 'bin', 'bundle')}"
    end

    private

    def ensure_working_directory(directory)
      unless File.directory?(directory)
        FileUtils.mkdir(directory)
      end
    end
  end
end
