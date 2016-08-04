require_relative 'spec_helper'
require 'open3'

extension_dir = YAML.load_file(ENV['BOSH_OPENSTACK_VALIDATOR_CONFIG'])['extensions']['path']
specs = Dir.glob(File.join(extension_dir, "*_spec.rb"))

if specs.size > 0

  openstack_suite.describe 'Extensions', position: 3, order: :global do
    specs.each do |file|
      puts "Evaluating extension: #{file}"
      binding.eval(File.read(file), file)
    end

  end
end

def delete(resource_type, id)
  sub_command = resource_type
  if resource_type == 'security'
    sub_command += ' group'
  elsif resource_type == 'ip'
    sub_command += ' floating'
  end
  STDERR.puts "delete command is: openstack #{sub_command} delete #{id}"
  output, error, _ = openstack(sub_command, 'delete', id)

  STDERR.puts "Cleanup result: #{output}, Error: #{error}"

  output
end

def openstack(*args, raise_error: true)
  parse_json = true
  if args[0] == 'router' && args[2] == 'subnet'
    parse_json = false
  elsif args[0] == 'ip' && (args[2] == 'add' || args[2] == 'remove')
    parse_json = false
  elsif args[1] == 'delete'
    parse_json = false
  end


  cmd = ['openstack'] + args
  cmd += auth_params
  cmd += ['-f json'] if parse_json

  full_cmd = cmd.join(' ')

  STDERR.puts full_cmd

  output, error, status =  Open3.capture3(full_cmd)

  if raise_error && status.exitstatus > 0
    fail(error)
  end

  if parse_json
    result = JSON.parse(output)
  elsif
  result = output
  end

  if args[1] == 'create' || args[2] == 'create'
    CfValidator.cli_resources.push( { type: args[0], id: result['id'] || result['name']} )
  end

  result
end

def neutron(*args)
  cmd = ['neutron'] + args
  cmd += auth_params
  cmd += ['-f json']
  full_cmd = cmd.join(' ')

  output, error, status =  Open3.capture3(full_cmd)

  STDERR.puts full_cmd

  if status.exitstatus > 0
    fail(error)
  end

  output
end

def auth_params
  cmd = ["--os-auth-url #{openstack_params['auth_url']}"]
  cmd += ["--os-username #{openstack_params['username']}"]
  cmd += ["--os-password #{openstack_params['password']}"]
  cmd += ["--os-project-name #{openstack_params['project']}"]
  cmd += ["--os-domain-name #{openstack_params['domain']}"]
  cmd += ["--os-user-domain-name #{openstack_params['domain']}"]
  cmd += ["--os-project-domain-name #{openstack_params['domain']}"]
  cmd += ["--os-region-name #{openstack_params['region_name']}"] if openstack_params['region_name']
  cmd += ["--insecure"] if openstack_params['connection_options'] && openstack_params['connection_options']['ssl_verify_peer'] == false
  cmd += ["--os-identity-api-version 3"]
end

def provides(name, value)
  CfValidator.globals[name] = value
end

def consumes(name)
  value = CfValidator.globals[name]

  if value == nil
    pending("Required resource '#{name}' does not exist.")
    raise "Error: global #{name} not defined"
  end
  value
end

def get(name)
  CfValidator.globals[name]
end