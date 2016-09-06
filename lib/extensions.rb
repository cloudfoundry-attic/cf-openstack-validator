require 'pathname'

class Extensions
  class << self
    def all
      config_path = File.expand_path(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])
      extensions_paths(config_path).map do |path|
        Dir.glob(File.join(path, '*_spec.rb'))
      end.flatten
    end

    def eval(specs, binding)
      specs.each do |file|
        puts "Evaluating extension: #{file}"
        begin
          binding.eval(File.read(file), file)
        rescue Exception => e
          puts e
          puts e.backtrace if ENV['VERBOSE_FORMATTER'] == 'true'
          raise e
        end
      end
      nil
    end

    private

    def extensions_paths(config_path)
      custom_paths = custom_extension_paths(config_path)

      if custom_paths.empty?
        path = default_extension_path(config_path)
        return [path] if File.directory?(path)
      else
        return custom_paths
      end

      []
    end

    def default_extension_path(config_path)
      File.join(File.dirname(config_path), 'extensions')
    end

    def get_from_hash(hash, *keys, default)
      unless keys.length == 0
        result = keys.inject hash do |hash, key|
          if hash && hash.is_a?(Hash)
            hash[key]
          end
        end
        result || default
      end
    end

    def custom_extension_paths(config_path)
      validator_config = YAML.load_file(config_path)

      paths = get_from_hash(validator_config, 'extensions', 'paths', [])
      paths.map do |path|
        resolved_path = if Pathname.new(path).absolute?
                          path
                        else
                          File.expand_path(path, File.dirname(config_path))
                        end

        raise StandardError, "'#{resolved_path}' is not a directory." unless File.directory?(resolved_path)

        resolved_path
      end
    end
  end
end