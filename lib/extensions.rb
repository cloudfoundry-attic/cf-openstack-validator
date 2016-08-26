require 'pathname'

class Extensions
  class << self
    def all
      config_path = File.expand_path(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])
      extensions_paths = default_extensions(config_path) + additional_extensions(config_path)

      extensions_paths.map do |path|

        if File.directory?(path)
          Dir.glob(File.join(path, '*_spec.rb'))
        elsif File.basename(path).end_with?('_spec.rb')
          [path]
        end

      end.flatten.compact.uniq
    end

    def eval(specs, binding)
      specs.each do |file|
        puts "Evaluating extension: #{file}"
        binding.eval(File.read(file), file)
      end
    end

    private

    def default_extensions(config_path)
      [File.join(File.dirname(config_path), 'extensions')]
    end

    def additional_extensions(config_path)
      validator_config = YAML.load_file(config_path)

      extensions = []

      if validator_config && validator_config['extensions']
        extensions = validator_config['extensions']
      end

      extensions.map do |extension|
        next unless extension['path']


        path = if Pathname.new(extension['path']).absolute?
                 extension['path']
               else
                 File.expand_path(extension['path'], File.dirname(config_path))
               end

        raise StandardError, "'#{path}' does not exist." unless File.exists?(path)

        path
      end.compact
    end
  end
end