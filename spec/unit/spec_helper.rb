require 'rspec'
require_relative '../../lib/validator'
require_relative '../../lib/validator/cli'

def expand_project_path(relative_project_path)
  File.expand_path(File.join('../../../', relative_project_path), __FILE__)
end

def tmp_path
  expand_project_path('tmp')
end