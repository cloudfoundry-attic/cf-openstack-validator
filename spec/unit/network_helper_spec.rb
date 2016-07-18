require_relative 'spec_helper'

describe NetworkHelper do
  describe '.next_free_ephemeral_port' do

    it 'uses the right Addrinfo for socket binding' do
      addr_info = Addrinfo.tcp('127.0.0.1', 0)
      expect(Addrinfo).to receive(:tcp).with('127.0.0.1', 0).and_return(addr_info)
      expect_any_instance_of(Socket).to receive(:bind).with(addr_info)

      NetworkHelper.next_free_ephemeral_port
    end

    it 'returns next ephemeral port number' do
      expect_any_instance_of(Socket).to receive(:local_address).and_return(Addrinfo.tcp('127.0.0.1', 4444))

      expect(NetworkHelper.next_free_ephemeral_port).to eq(4444)
    end

  end
end
