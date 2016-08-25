require 'pathname'

class Extensions
  class << self
    def all
      config_path = File.expand_path(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])
      extensions_path = extension_path(config_path) || default_extension_path(config_path)

      raise StandardError, "'#{extensions_path}' is not a directory." unless File.directory?(extensions_path)
      Dir.glob(File.join(extensions_path, '*_spec.rb'))
    end

    def eval(specs, binding)
      specs.each do |file|
        puts "Evaluating extension: #{file}"
        binding.eval(File.read(file), file)
      end
    end

    private

    def default_extension_path(config_path)
      File.join(File.dirname(config_path), 'extensions')
    end

    def extension_path(config_path)
      validator_config = YAML.load_file(config_path)

      extensions = if validator_config
        validator_config['extensions']
      end

      path = if extensions
        extensions['path']
      end

      if path
        if Pathname.new(extensions['path']).absolute?
          extensions['path']
        else
          File.expand_path(extensions['path'], File.dirname(config_path))
        end
      end
    end
  end
end