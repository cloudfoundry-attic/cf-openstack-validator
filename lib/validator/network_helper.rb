require 'socket'

module Validator
  class NetworkHelper
    def self.next_free_ephemeral_port
      socket = Socket.new(:INET, :STREAM, 0)
      socket.bind(Addrinfo.tcp('127.0.0.1', 0))
      port = socket.local_address.ip_port
      socket.close
      port
    end

    def self.vm_ip_to_ssh(vm_id, config, compute)
      if config.validator['use_external_ip']
        config.validator['floating_ip']
      else
        server = compute.servers.get(vm_id)
        server.addresses.values.first.dig(0,'addr')
      end
    end

    def self.ssh_port_open?(configured_security_groups, network)
      check_remote_group_id_empty = Validator::Api.configuration.validator['use_external_ip']
      port_open_in_any_security_group?('ingress', 22, 'tcp', configured_security_groups, check_remote_group_id_empty, network)
    end

    def self.port_open_in_any_security_group?(direction, port, protocol, security_groups, check_remote_group_id_empty = false, network)
      port_open = false
      security_groups.each { |security_group| port_open ||= port_open?(direction, port, protocol, security_group, check_remote_group_id_empty, network) }
      port_open
    end

    def self.port_open?(direction, port, protocol, security_group, check_remote_group_id_empty = false, network)
      security_group = network.security_groups.find { |sg| sg.name == security_group }
      rule = security_group.security_group_rules.find { |rule|
        result = rule.direction == direction && rule.ethertype == 'IPv4' && protocol_included?(rule, protocol) && port_in_range?(port, rule)
        if check_remote_group_id_empty
          result = result && rule.remote_group_id == nil
        end
        result
      }
      rule != nil
    end

    def self.port_in_range?(port, rule)
      any_range?(rule) || (rule.port_range_min <= port && port <= rule.port_range_max)
    end

    def self.any_range?(rule)
      rule.port_range_min == nil && rule.port_range_max == nil
    end

    def self.protocol_included?(rule, protocol)
      rule.protocol == nil || rule.protocol == protocol
    end
  end
end