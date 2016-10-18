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

          exit_status = wait_thr.value
          unless exit_status == 0
            raise ErrorWithLogDetails.new(log_path)
          end
        end
      end
    end

    private

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