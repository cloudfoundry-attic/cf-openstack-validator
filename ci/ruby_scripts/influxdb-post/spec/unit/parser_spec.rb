require_relative '../../lib/parser'

describe Parser do
  subject { Parser.new(File.join('spec', 'assets', 'small-stats.log')) }

  describe '#new' do
    it 'stores the json data into a ruby hash' do
      expect(subject.data).to eq([{'request' => {'method' => 'create_stemcell', 'arguments' => ['/image-path',{}], 'context' =>{}}, 'duration' => 15.95},{'request' => {'method' => 'something-else'}, 'duration' => 5.0}])
    end
  end

  describe '#to_influx' do
    before do
      allow(Parser).to receive(:current_time_in_influx_format).and_return(1434055562000000000)
    end

    it 'returns a string in influxdb format' do
      expected_string = "cpi_duration,method=create_stemcell value=15.95 1434055562000000000\n" +
                        'cpi_duration,method=something-else value=5.0 1434055562000000000'
      expect(subject.to_influx).to eq(expected_string)
    end

    context 'with a parameter' do
      it 'adds it as a tag' do
        expected_string = "cpi_duration,method=create_stemcell,landscape=my-landscape value=15.95 1434055562000000000\n" +
                          'cpi_duration,method=something-else,landscape=my-landscape value=5.0 1434055562000000000'
        expect(subject.to_influx(landscape: 'my-landscape')).to eq(expected_string)
      end

      it 'raises if the parameter is not a hash' do
        expect {
          subject.to_influx('hello')
        }.to raise_error(ArgumentError)
      end
    end
  end
end
