require 'rspec'
require 'fileutils'
require 'yaml'
require_relative '../../lib/validator'
require_relative '../../lib/validator/cli'

def expand_project_path(relative_project_path)
  File.expand_path(File.join('../../../', relative_project_path), __FILE__)
end

def tmp_path
  expand_project_path('tmp')
end

def read_valid_config
  YAML.load_file(expand_project_path(File.join('spec', 'assets', 'validator.yml')))
end