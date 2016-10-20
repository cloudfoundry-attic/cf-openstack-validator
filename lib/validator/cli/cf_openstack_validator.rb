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

    def install_cpi_release
      extracted_release_path = deep_extract_release(@context.cpi_release)
      release_packages(extracted_release_path, ['ruby_openstack_cpi']).each { |package| compile_package(package) }
      render_cpi_executable
    end

    def deep_extract_release(archive)
      FileUtils.mkdir_p(@context.extracted_cpi_release_dir)
      Untar.extract_archive(archive, @context.extracted_cpi_release_dir)
      extract_target = File.join(@context.working_dir, File.basename(archive, '.tgz'))
      packages_path = File.join(extract_target, 'packages')
      Dir.glob(File.join(packages_path, '*')).each do |package|
        Untar.extract_archive(package, File.join(packages_path, File.basename(package, '.tgz')))
      end
      extract_target
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
      output, status = Open3.capture2e(env, "#{@context.bundle_command} install --local", :unsetenv_others => true)
      log_path = File.join(log_directory, 'bundle_install.log')
      File.write(log_path, output)
      raise_on_failing_status(status.exitstatus, log_path)
    end

    def compile_package(package_path)
      package_name = File.basename(package_path)
      compilation_base_dir = File.join(@context.working_dir, 'packages')
      package_compilation_dir = File.join(@context.working_dir, 'packages', package_name)
      FileUtils.mkdir_p(package_compilation_dir)

      packaging_script = File.join(package_path, 'packaging')
      FileUtils.chmod('+x', packaging_script)
      env = {
          'BOSH_PACKAGES_DIR' => compilation_base_dir,
          'BOSH_INSTALL_TARGET' => package_compilation_dir
      }
      log_path = File.join(log_directory, "packaging-#{package_name}.log")
      File.open(log_path, 'w') do |file|
        Open3.popen2e(env, packaging_script, :chdir=>package_path) do |_, stdout_err, wait_thr|
          stdout_err.each do |line|
            file.write line
            file.flush
          end
          raise_on_failing_status(wait_thr.value, log_path)
        end
      end
    end

    def generate_cpi_config
      config = CfValidator.configuration(@context.config).all
      ok, error_message = ValidatorConfig.validate(config)
      unless ok
        return ok, "`validator.yml` is not valid:\n#{error_message}"
      end
      cpi_config_content = JSON.pretty_generate(Converter.to_cpi_json(CfValidator.configuration.openstack))
      puts "CPI will use the following configuration: \n#{cpi_config_content}"
      File.write(File.join(@context.working_dir, 'cpi.json'), cpi_config_content)
      return ok, nil
    end

    def print_gem_environment
      env = {
          'PATH' => @context.path_environment,
          'GEM_PATH' => @context.gems_folder,
          'GEM_HOME' => @context.gems_folder
      }
      output, status = Open3.capture2e(env, "#{@context.bundle_command} exec gem environment && #{@context.bundle_command} list", :unsetenv_others => true)
      log_path = File.join(log_directory, 'gem_environment.log')
      File.write(log_path, output)
      raise_on_failing_status(status.exitstatus, log_path)
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
      }

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
        stdout_out.each do |line|
          puts line
        end
        raise_on_failing_status(wait_thr.value, log_path)
      end
    end

    def installation_exists?
      return false unless File.exist?(@context.working_dir)
      !is_dir_empty?
    end

    def check_installation?
      unless File.exist?(File.join(@context.working_dir, '.completed'))
        error_message = "The CPI installation did not finish successfully.\n" +
            "Execute 'rm -rf #{@context.working_dir}' and run the tests again."
        return [false, error_message]
      end

      if File.read(File.join(@context.working_dir, '.completed')) != @context.cpi_release
        error_message = "Provided CPI and pre-installed CPI don't match.\n" +
            "Execute 'rm -rf #{@context.working_dir}' and run the tests again."
        return [false, error_message]
      end

      [true, nil]
    end

    def save_cpi_release_version
      File.write(File.join(@context.working_dir, '.completed'), @context.cpi_release)
    end

    def print_working_dir
      puts "Using '#{@context.working_dir}' as working directory"
    end

    private

    def is_dir_empty?
      entries = Dir.entries(@context.working_dir) - ['.', '..']
      entries.empty?
    end

    def raise_on_failing_status(exit_status, log_path)
      unless exit_status == 0
        raise ErrorWithLogDetails.new(log_path)
      end
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