module Validator::Cli
  Options = Struct.new(:packages_dir, :log_path, :stemcell_path, :cpi_bin_path, :config_path, :cpi_config, :skip_cleanup?, :verbose?)

  class Context

    attr_reader :openstack_cpi_bin_from_env, :working_dir, :config, :cpi_json_path, :jobs_config_path, :cacert_path

    attr_accessor :cpi_bin_path, :cpi_release_path

    def initialize(cli_options)
      @cli_options = cli_options
      @cpi_release_path = @cli_options[:cpi_release]
      @working_dir = @cli_options[:working_dir] || "#{ENV['HOME']}/.cf-openstack-validator"
      ensure_working_directory(@working_dir)
      @working_dir = File.expand_path(@working_dir)
      @path_from_env = ENV['PATH']
      @openstack_cpi_bin_from_env = ENV['OPENSTACK_CPI_BIN']
      @cpi_bin_path = File.join(@working_dir, 'cpi')
      @config = Validator::Api::Configuration.new(config_path)
      @jobs_config_path = File.join(@working_dir, 'jobs', 'openstack_cpi', 'config')
      @cpi_json_path = File.join(@jobs_config_path, 'cpi.json')
      @cacert_path = File.join(@jobs_config_path, 'cacert.pem')
    end

    def tag
      @cli_options[:tag]
    end

    def skip_cleanup?
      @cli_options[:skip_cleanup]
    end

    def verbose?
      @cli_options[:verbose]
    end

    def fail_fast?
      @cli_options[:fail_fast]
    end

    def stemcell
      @cli_options[:stemcell]
    end

    def config_path
      @cli_options[:config_path]
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

    def create_validator_options
      Options.new(
          packages_path,
          File.join(working_dir, 'logs'),
          File.join(working_dir, 'stemcell'),
          cpi_bin_path,
          config_path,
          cpi_json_path,
          skip_cleanup?,
          verbose?
      ).freeze
    end

    private

    def ensure_working_directory(directory)
      unless File.directory?(directory)
        FileUtils.mkdir(directory)
      end
    end
  end
end
