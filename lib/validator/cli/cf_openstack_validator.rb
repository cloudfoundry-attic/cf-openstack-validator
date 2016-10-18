module Validator::Cli
  class CfOpenstackValidator

    class << self
      def create(options)
        ensure_working_directory(options[:working_dir])
        CfOpenstackValidator.new(options)
      end

      def ensure_working_directory(path)
        if path
          FileUtils.mkdir_p(path).first
        else
          Dir.mktmpdir
        end
      end
    end

    def initialize(options)
      @working_dir = options[:working_dir]
      @tag = options[:tag]
      @skip_cleanup = options[:skip_cleanup]
      @verbose = options[:verbose]
      @fail_fast = options[:fail_fast]
      @validator_dir = File.expand_path('../../../../', __FILE__)
    end

    def install_cpi_release(path)
      extracted_release_path = deep_extract_release(path)
      release_packages(extracted_release_path).each { |package| compile_package(package) }
      render_cpi_executable
    end

    def deep_extract_release(archive)
      Untar.extract_archive(archive, @working_dir)
      extract_target = File.join(@working_dir, File.basename(archive, '.tgz'))
      packages_path = File.join(extract_target, 'packages')
      Dir.glob(File.join(packages_path, '*')).each do |package|
        Untar.extract_archive(package, File.join(packages_path, File.basename(package, '.tgz')))
      end
      extract_target
    end

    def extract_stemcell(archive)
      stemcell_path = File.join(@working_dir, 'stemcell')
      FileUtils.mkdir_p(stemcell_path)
      Untar.extract_archive(archive, stemcell_path)
    end

    def prepare_ruby_environment(path_env_var, gems_path, bundle_command)
      env = {
          'BUNDLE_CACHE_PATH' => 'vendor/package',
          'PATH' => path_env_var,
          'GEM_PATH' => gems_path,
          'GEM_HOME' => gems_path
      }
      output, status = Open3.capture2e(env, "#{bundle_command} install --local")
      log_path = File.join(log_directory, 'bundle_install.log')
      File.write(log_path, output)
      raise_on_failing_status(status.exitstatus, log_path)
    end

    def compile_package(package_path)
      target = File.join(@working_dir, 'packages')
      package_name = File.basename(package_path)
      FileUtils.mkdir_p(File.join(target, package_name))

      packaging_script = File.join(package_path, 'packaging')
      FileUtils.chmod('+x', packaging_script)
      env = {
          'BOSH_PACKAGES_DIR' => File.join(target, package_name),
          'BOSH_INSTALL_TARGET' => target
      }
      log_path = File.join(log_directory, "packaging-#{package_name}.log")
      File.open(log_path, 'w') do |file|
        Open3.popen2e(env, packaging_script) do |_, stdout_err, wait_thr|
          stdout_err.each do |line|
            file.write line
          end
          raise_on_failing_status(wait_thr.value, log_path)
        end
      end
    end

    def path_environment
      cpi_executable_path = File.join(@working_dir, 'packages', 'ruby_openstack_cpi', 'bin')
      "#{cpi_executable_path}:#{ENV['PATH']}"
    end

    def gems_folder
      File.join(tmp_path, 'packages', 'ruby_openstack_cpi', 'lib', 'ruby', 'gems', '*')
    end

    def bundle_command
      "BUNDLE_GEMFILE=#{File.join(@validator_dir, 'Gemfile')} #{File.join(@working_dir, 'packages', 'ruby_openstack_cpi', 'bin', 'bundle')}"
    end

    def generate_cpi_config(validator_config_path)
      cpi_config = File.join(@working_dir, 'cpi.json')

      #TODO refactor this at the end
      ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'] = validator_config_path
      ok, error_message = ValidatorConfig.validate(CfValidator.configuration.all)
      unless ok
        #TODO may be we should raise a specific exception?
        raise "`validator.yml` is not valid:\n#{error_message}"
      end
      cpi_config_content = JSON.pretty_generate(Converter.to_cpi_json(CfValidator.configuration.openstack))
      puts "CPI will use the following configuration: \n#{cpi_config_content}"
      File.write(cpi_config, cpi_config_content)
    end

    def print_gem_environment(path_env_var, gems_path, bundle_command)
      env = {
          'PATH' => path_env_var,
          'GEM_PATH' => gems_path,
          'GEM_HOME' => gems_path
      }
      output, status = Open3.capture2e(env, "#{bundle_command} exec gem environment && #{bundle_command} list")
      log_path = File.join(log_directory, 'gem_environment.log')
      File.write(log_path, output)
      raise_on_failing_status(status.exitstatus, log_path)
    end

    def execute_specs(validator_config_path, path_env_var, gems_path, bundle_command)
      env = {
          'PATH' => path_env_var,
          'GEM_PATH' => gems_path,
          'GEM_HOME' => gems_path,
          'BOSH_PACKAGES_DIR' => File.join(@working_dir, 'packages'),
          'BOSH_OPENSTACK_CPI_LOG_PATH' => File.join(@working_dir, 'logs'),
          'BOSH_OPENSTACK_STEMCELL_PATH' => File.join(@working_dir, 'stemcell'),
          'BOSH_OPENSTACK_CPI_PATH' => File.join(@working_dir, 'cpi'),
          'BOSH_OPENSTACK_VALIDATOR_CONFIG' => validator_config_path,
          'BOSH_OPENSTACK_CPI_CONFIG' => File.join(@working_dir, 'cpi.json'),
          'BOSH_OPENSTACK_VALIDATOR_SKIP_CLEANUP' => @skip_cleanup,
          'VERBOSE_FORMATTER' => @verbose,
          'http_proxy' => ENV['http_proxy'],
          'https_proxy' => ENV['https_proxy'],
          'no_proxy' => ENV['no_proxy'],
          'HOME' => ENV['HOME']
      }

      rspec_command = [
          "#{bundle_command} exec rspec #{File.join(@validator_dir, 'src', 'specs')}"
      ]
      rspec_command += ["--tag #{@tag}"] if @tag
      rspec_command += ['--fail-fast'] if @fail_fast
      rspec_command += [
          '--order defined',
          "--color --require #{File.join(@validator_dir, 'lib', 'formatter.rb')}",
          '--format TestsuiteFormatter'
      ]
      log_path = File.join(log_directory, 'testsuite.log')
      File.open(log_path, 'w') do |file|
        Open3.popen2e(env, rspec_command.join(' ')) do |stdout_out, stdout_err, wait_thr|
          stdout_err.each do |line|
            file.write line
          end
          stdout_out.each do |line|
            puts line
          end
          raise_on_failing_status(wait_thr.value, log_path)
        end
      end
    end

    def installation_exists?
      entries = Dir.entries(@working_dir) - ['.', '..']
      !entries.empty?
    end

    def check_installation?(cpi_release)
      unless File.exist?(File.join(@working_dir, '.completed'))
        error_message = "The CPI installation did not finish successfully.\n" +
            "Execute 'rm -rf #{@working_dir}' and run the tests again."
        return [false, error_message]
      end

      if File.read(File.join(@working_dir, '.completed')) != cpi_release
        error_message = "Provided CPI and pre-installed CPI don't match.\n" +
            "Execute 'rm -rf #{@working_dir}' and run the tests again."
        return [false, error_message]
      end

      [true, nil]
    end

    def save_cpi_release_version(cpi_release)
      File.write(File.join(@working_dir, '.completed'), cpi_release)
    end

    private

    def raise_on_failing_status(exit_status, log_path)
      unless exit_status == 0
        raise ErrorWithLogDetails.new(log_path)
      end
    end

    def log_directory
      FileUtils.mkdir_p(File.join(@working_dir, 'logs')).first
    end

    def render_cpi_executable
      cpi_content = <<EOF
#!/usr/bin/env bash

BOSH_PACKAGES_DIR=\${BOSH_PACKAGES_DIR:-#{File.join(@working_dir, 'packages')}}

PATH=\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin:\$PATH
export PATH

export BUNDLE_GEMFILE=\$BOSH_PACKAGES_DIR/bosh_openstack_cpi/Gemfile

bundle_cmd="\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin/bundle"
read -r INPUT
echo \$INPUT | \$bundle_cmd exec \$BOSH_PACKAGES_DIR/bosh_openstack_cpi/bin/openstack_cpi #{File.join(@working_dir, 'cpi.json')}
EOF
      File.write(File.join(@working_dir, 'cpi'), cpi_content)
      FileUtils.chmod('+x',File.join(@working_dir, 'cpi'))
    end

    def release_packages(release_path)
      Dir.glob(File.join(release_path, 'packages', '*')).select { |path| File.directory?(path) }
    end
  end
end