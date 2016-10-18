require_relative '../../spec_helper'

def dummy_file_path
  File.join(tmp_path, 'dummy.content')
end

module Validator::Cli
  describe Untar do
    after(:each) do
      if File.exists?(tmp_path)
        FileUtils.rm_r(tmp_path)
      end
    end

    describe '.extract_archive' do
      it 'should extract tar archive' do
        Untar.extract_archive(expand_project_path('spec/assets/dummy.tgz'), tmp_path)

        expect(File.exists?(dummy_file_path)).to be(true)
      end

      it 'throws exception when untar fails' do
        expect {
          Untar.extract_archive('non-existing-path', 'another-non-existing-path')
        }.to raise_error(StandardError, /Error extracting/)
      end
    end
  end
end