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
        generate_cpi_config
        prepare_cpi_release
        extract_stemcell
        prepare_ruby_environment
        print_gem_environment
        execute_specs
      rescue Validator::Api::ValidatorError => e
        $stderr.puts(e.message)
        Kernel.exit 1
      end
    end

    def prepare_cpi_release
      if @context.cpi_release_path
        install_cpi_release
      elsif cpi_bin_env?
        add_cpi_bin_env
      else
        install_cpi_release_from_config
      end
    end

    def install_cpi_release_from_config
      cpi_release_path = File.join(@context.working_dir, 'bosh-openstack-cpi-release.tgz')
      if last_download_successful?
        puts "Skipping CPI release download. Using CPI at '#{cpi_release_path}'."
      else
        puts "Downloading CPI release from '#{configured_cpi_release['url']}' to '#{cpi_release_path}'"
        download_cpi_release(configured_cpi_release['url'], cpi_release_path)
      end
      validate_download(cpi_release_path)
      update_download_state
      @context.cpi_release_path = cpi_release_path
      install_cpi_release
    end

    def with_state_file(message, source, destination)
      sha1 = file_sha1(source)
      completed_marker_path = File.join(destination, '.completed')
      if File.exists?(completed_marker_path) && File.read(completed_marker_path) == sha1
        puts message
        return
      end

      if block_given?
        yield
      end

      File.write(File.join(destination, '.completed'), sha1)
    end

    def install_cpi_release
      message = "CPI '#{@context.cpi_release_path}' is already installed. Skipping installation"
      with_state_file(message, @context.cpi_release_path, @context.extracted_cpi_release_dir) do
        delete_old_cpi
        deep_extract_release(@context.cpi_release_path)
        release_packages(@context.extracted_cpi_release_dir, ['ruby_openstack_cpi']).each do |package|
          compile_package(package)
        end
        render_cpi_executable
      end
    end

    def deep_extract_release(archive)
      puts 'Extracting CPI release'
      FileUtils.mkdir_p(@context.extracted_cpi_release_dir)
      Untar.extract_archive(archive, @context.extracted_cpi_release_dir)
      packages_path = File.join(@context.extracted_cpi_release_dir, 'packages')
      Dir.glob(File.join(packages_path, '*')).each do |package|
        Untar.extract_archive(package, File.join(packages_path, File.basename(package, '.tgz')))
      end
    end

    def extract_stemcell
      stemcell_path = File.join(@context.working_dir, 'stemcell')
      message = "Stemcell '#{@context.stemcell}' is already extracted to '#{stemcell_path}'"
      with_state_file(message, @context.stemcell, stemcell_path) do
        if File.exists?(stemcell_path)
          puts 'Deleting old stemcell'
          FileUtils.rm_r(stemcell_path)
        end
        FileUtils.mkdir_p(stemcell_path)
        puts 'Extracting stemcell'
        Untar.extract_archive(@context.stemcell, stemcell_path)
      end
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
      ok, error_message = Validator::ConfigValidator.validate(@context.config.all)
      unless ok
        raise Validator::Api::ValidatorError, "`validator.yml` is not valid:\n#{error_message}"
      end
      cpi_config_content = JSON.pretty_generate(Validator::Converter.to_cpi_json(@context.config.openstack))
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
          'BOSH_OPENSTACK_CPI_PATH' => @context.cpi_bin_path,
          'BOSH_OPENSTACK_VALIDATOR_CONFIG' => @context.config_path,
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
          "--color --tty --require #{File.join(@context.validator_root_dir, 'lib', 'validator', 'formatter.rb')}",
          '--format Validator::TestsuiteFormatter',
          "2> #{log_path}"
      ]
      Open3.popen3(env, rspec_command.join(' '), :unsetenv_others => true) do |_, stdout_out, _, wait_thr|
        stdout_out.each_char {|c| print c }

        unless wait_thr.value == 0
          raise ErrorWithLogDetails.new("Executing '#{rspec_command}' failed", log_path)
        end
      end
    end

    def print_working_dir
      puts "Using '#{@context.working_dir}' as working directory"
    end

    def download_cpi_release(download_url, cpi_release_path)
      temp_download_file = open(download_url)
      File.rename(temp_download_file, cpi_release_path)
    end

    def add_cpi_bin_env
      unless File.exists?(@context.openstack_cpi_bin_from_env)
        raise Validator::Api::ValidatorError, "CPI executable is not found at OPENSTACK_CPI_BIN=#{@context.openstack_cpi_bin_from_env}"
      end

      if File.directory?(@context.openstack_cpi_bin_from_env)
        raise Validator::Api::ValidatorError, "OPENSTACK_CPI_BIN points to a folder and not an executable. (#{@context.openstack_cpi_bin_from_env})"
      end

      @context.cpi_bin_path = @context.openstack_cpi_bin_from_env
      puts "OPENSTACK_CPI_BIN is set in ENV. Using already installed OpenStack CPI from `#{@context.openstack_cpi_bin_from_env}`."
    end

    private

    def update_download_state
      File.write(download_state_file, configured_cpi_release['url'])
    end

    def validate_download(cpi_release_path)
      cpi_release_sha1 = file_sha1(cpi_release_path)
      if (cpi_release_sha1 != configured_cpi_release['sha1'])
        raise Validator::Api::ValidatorError, "Configured SHA1 '#{configured_cpi_release['sha1']}' does not match downloaded CPI SHA1 '#{cpi_release_sha1}'"
      end
    end

    def file_sha1(file_path)
      Digest::SHA1.file(file_path).to_s
    end

    def last_download_successful?
      return false if !File.exists?(download_state_file)
      File.read(download_state_file) == configured_cpi_release['url']
    end

    def download_state_file
      File.join(@context.working_dir, '.download_completed')
    end

    def configured_cpi_release
      @context.config.validator['releases'][0]
    end

    def cpi_bin_env?
      @context.openstack_cpi_bin_from_env != nil
    end

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

BOSH_PACKAGES_DIR=\${BOSH_PACKAGES_DIR:-#{@context.packages_path}}

PATH=\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin:\$PATH
export PATH

export BUNDLE_GEMFILE=\$BOSH_PACKAGES_DIR/bosh_openstack_cpi/Gemfile

bundle_cmd="\$BOSH_PACKAGES_DIR/ruby_openstack_cpi/bin/bundle"
read -r INPUT
echo \$INPUT | \$bundle_cmd exec \$BOSH_PACKAGES_DIR/bosh_openstack_cpi/bin/openstack_cpi #{File.join(@context.working_dir, 'cpi.json')}
EOF
      File.write(@context.cpi_bin_path, cpi_content)
      FileUtils.chmod('+x', @context.cpi_bin_path)
    end

    def delete_old_cpi
      if File.exists?(@context.extracted_cpi_release_dir)
        puts 'Deleting old CPI installation'
        FileUtils.rm_r(File.join(@context.extracted_cpi_release_dir))
      end
      File.delete(@context.cpi_bin_path) if File.exists?(@context.cpi_bin_path)
      FileUtils.rm_r(@context.packages_path) if File.exists?(@context.packages_path)
    end
  end
end