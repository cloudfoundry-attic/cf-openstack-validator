module Validator::Cli
  class CfOpenstackValidator

    class << self
      def create(options)
        CfOpenstackValidator.new(options)
      end
    end

    def initialize(context)
      @context = context
    end

    def run
      begin
        print_working_dir
        unless installation_exists?
          install_cpi_release
          extract_stemcell
          save_cpi_release_version
        end

        check_installation
        prepare_ruby_environment
        generate_cpi_config

        print_gem_environment

        execute_specs
      rescue ValidatorError => e
        $stderr.puts(e.message)
        Kernel.exit 1
      end
    end

    def install_cpi_release
      deep_extract_release(@context.cpi_release)
      release_packages(@context.extracted_cpi_release_dir, ['ruby_openstack_cpi']).each { |package| compile_package(package) }
      render_cpi_executable
    end

    def deep_extract_release(archive)
      FileUtils.mkdir_p(@context.extracted_cpi_release_dir)
      Untar.extract_archive(archive, @context.extracted_cpi_release_dir)
      packages_path = File.join(@context.extracted_cpi_release_dir, 'packages')
      Dir.glob(File.join(packages_path, '*')).each do |package|
        Untar.extract_archive(package, File.join(packages_path, File.basename(package, '.tgz')))
      end
    end

    def extract_stemcell
      stemcell_path = File.join(@context.working_dir, 'stemcell')
      FileUtils.mkdir_p(stemcell_path)
      Untar.extract_archive(@context.stemcell, stemcell_path)
    end

    def release_packages(release_path, install_order=[])
      packages = Dir.glob(File.join(release_path, 'packages', '*')).select { |path| File.directory?(path) }
      return packages if install_order.empty?
      ordered_packages = []
      install_order.each do |package_name|
        package_path = packages.find { |p| File.basename(p) == package_name }
        ordered_packages << package_path if package_path
      end

      all_other_packages = packages - ordered_packages
      ordered_packages + all_other_packages
    end

    def prepare_ruby_environment
      env = {
          'BUNDLE_CACHE_PATH' => 'vendor/package',
          'PATH' => @context.path_environment,
          'GEM_PATH' => @context.gems_folder,
          'GEM_HOME' => @context.gems_folder
      }
      log_path = File.join(log_directory, 'bundle_install.log')

      execute_command(
          env: env,
          command: "#{@context.bundle_command} install --local",
          log_path: log_path
      )
    end

    def compile_package(package_path)
      package_name = File.basename(package_path)
      compilation_base_dir = File.join(@context.working_dir, 'packages')
      package_compilation_dir = File.join(@context.working_dir, 'packages', package_name)

      puts "Compiling package '#{package_name}' into '#{package_compilation_dir}'"

      FileUtils.mkdir_p(package_compilation_dir)

      packaging_script = File.join(package_path, 'packaging')
      FileUtils.chmod('+x', packaging_script)
      env = {
          'BOSH_PACKAGES_DIR' => compilation_base_dir,
          'BOSH_INSTALL_TARGET' => package_compilation_dir,
          'PATH' => @context.path_environment
      }
      log_path = File.join(log_directory, "packaging-#{package_name}.log")

      execute_command(
          env: env,
          command: packaging_script,
          chdir: package_path,
          log_path: log_path
      )
    end

    def execute_command(env:, command:, log_path:, **options)
      options.merge!({unsetenv_others: true})

      File.open(log_path, 'w') do |file|
        Open3.popen2e(env, command, options) do |_, stdout_err, wait_thr|
          stdout_err.each do |line|
            file.write line
            file.flush
          end
          unless wait_thr.value == 0
            raise ErrorWithLogDetails.new("Executing '#{command}' failed", log_path)
          end
        end
      end
    end

    def generate_cpi_config
      config = CfValidator.configuration(@context.config).all
      ok, error_message = ValidatorConfig.validate(config)
      unless ok
        raise ValidatorError, "`validator.yml` is not valid:\n#{error_message}"
      end
      cpi_config_content = JSON.pretty_generate(Converter.to_cpi_json(CfValidator.configuration.openstack))
      puts "CPI will use the following configuration: \n#{cpi_config_content}"
      File.write(File.join(@context.working_dir, 'cpi.json'), cpi_config_content)
    end

    def print_gem_environment
      env = {
          'PATH' => @context.path_environment,
          'GEM_PATH' => @context.gems_folder,
          'GEM_HOME' => @context.gems_folder
      }
      log_path = File.join(log_directory, 'gem_environment.log')
      execute_command(
          env: env,
          command: "#{@context.bundle_command} exec gem environment && #{@context.bundle_command} list",
          log_path: log_path
      )
    end

    def execute_specs
      env = {
          'PATH' => @context.path_environment,
          'GEM_PATH' => @context.gems_folder,
          'GEM_HOME' => @context.gems_folder,
          'BOSH_PACKAGES_DIR' => File.join(@context.working_dir, 'packages'),
          'BOSH_OPENSTACK_CPI_LOG_PATH' => File.join(@context.working_dir, 'logs'),
          'BOSH_OPENSTACK_STEMCELL_PATH' => File.join(@context.working_dir, 'stemcell'),
          'BOSH_OPENSTACK_CPI_PATH' => File.join(@context.working_dir, 'cpi'),
          'BOSH_OPENSTACK_VALIDATOR_CONFIG' => @context.config,
          'BOSH_OPENSTACK_CPI_CONFIG' => File.join(@context.working_dir, 'cpi.json'),
          'BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP' => @context.skip_cleanup?.to_s,
          'VERBOSE_FORMATTER' => @context.verbose?.to_s,
          'http_proxy' => ENV['http_proxy'],
          'https_proxy' => ENV['https_proxy'],
          'no_proxy' => ENV['no_proxy'],
          'HOME' => ENV['HOME']
      }.merge(enable_fog_logging_to_stderr)

      rspec_command = [
          "#{@context.bundle_command} exec rspec #{File.join(@context.validator_root_dir, 'src', 'specs')}"
      ]
      log_path = File.join(log_directory, 'testsuite.log')
      rspec_command += ["--tag #{@context.tag}"] if @context.tag
      rspec_command += ['--fail-fast'] if @context.fail_fast?
      rspec_command += [
          '--order defined',
          "--color --tty --require #{File.join(@context.validator_root_dir, 'lib', 'formatter.rb')}",
          '--format TestsuiteFormatter',
          "2> #{log_path}"
      ]
      Open3.popen3(env, rspec_command.join(' '), :unsetenv_others => true) do |_, stdout_out, _, wait_thr|
        stdout_out.each_char {|c| print c }

        unless wait_thr.value == 0
          raise ErrorWithLogDetails.new("Executing '#{rspec_command}' failed", log_path)
        end
      end
    end

    def installation_exists?
      return false unless File.exist?(@context.working_dir)
      !is_dir_empty?
    end

    def check_installation
      unless File.exist?(File.join(@context.working_dir, '.completed'))
        error_message = "The CPI installation did not finish successfully.\n" +
            "Execute 'rm -rf #{@context.working_dir}' and run the tests again."
        raise ValidatorError, error_message
      end

      if File.read(File.join(@context.working_dir, '.completed')) != @context.cpi_release
        error_message = "Provided CPI and pre-installed CPI don't match.\n" +
            "Execute 'rm -rf #{@context.working_dir}' and run the tests again."
        raise ValidatorError, error_message
      end
    end

    def save_cpi_release_version
      File.write(File.join(@context.working_dir, '.completed'), @context.cpi_release)
    end

    def print_working_dir
      puts "Using '#{@context.working_dir}' as working directory"
    end

    private

    def enable_fog_logging_to_stderr
      { 'EXCON_DEBUG' => 'true' }
    end

    def is_dir_empty?
      entries = Dir.entries(@context.working_dir) - ['.', '..']
      entries.empty?
    end

    def log_directory
      FileUtils.mkdir_p(File.join(@context.working_dir, 'logs')).first
    end

    def render_cpi_executable
      cpi_content = <<EOF
#!/usr/bin/env bash

BOSH_PACKAGES_DIR=\${BOSH_PACKAGES_DIR:-#{File.join(@context.working_dir, 'packages')}}

PATH=\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin:\$PATH
export PATH

export BUNDLE_GEMFILE=\$BOSH_PACKAGES_DIR/bosh_openstack_cpi/Gemfile

bundle_cmd="\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin/bundle"
read -r INPUT
echo \$INPUT | \$bundle_cmd exec \$BOSH_PACKAGES_DIR/bosh_openstack_cpi/bin/openstack_cpi #{File.join(@context.working_dir, 'cpi.json')}
EOF
      File.write(File.join(@context.working_dir, 'cpi'), cpi_content)
      FileUtils.chmod('+x',File.join(@context.working_dir, 'cpi'))
    end
  end
end