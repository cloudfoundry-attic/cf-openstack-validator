require 'fileutils'

fdescribe 'Cloud Controller using Swift as blobstore' do
  let(:storage) {
    storage_config = {:openstack_temp_url_key => Validator::Api.configuration.extensions['object_storage']['openstack']['openstack_temp_url_key']}
    Validator::Api::FogOpenStack.storage(storage_config)
  }
  let(:ssl_ca_file) { Validator::Api.configuration.openstack['connection_options']['ssl_ca_file'] }

  before(:all) do
    @resource_tracker = Validator::Api::ResourceTracker.create
  end

  it 'can create a directory' do
    directory_id = @resource_tracker.produce(:directories, provide_as: :root) {
      storage.directories.create({
          key: 'validator-key',
          public: false
      }).key
    }

    expect(directory_id).to_not be_nil
  end

  it 'can get a directory' do
    expect(test_directory.key).to eq('validator-key')
  end

  it 'can upload a blob' do
    directory = test_directory
    expect{
      @resource_tracker.produce(:files, provide_as: :simple_blob) do
        file = directory.files.create({
          key: 'validator-test-blob',
          body: 'Hello World',
          content_type: 'text/plain',
          public: false
        })
        [directory.key, file.key]
      end
    }.not_to raise_error
  end

  it 'can create a temporary url' do
    _, file_key = @resource_tracker.consumes(:simple_blob)
    root_dir = test_directory
    file = root_dir.files.get(file_key)

    url = file.url(Time.now.utc + 360000)

    expect(url).to_not be_nil

    options = {}
    options[:ssl_ca_file] = ssl_ca_file if ssl_ca_file
    response = Excon.get(url, options)
    error_message = <<EOT
Unable to access the tempurl:
#{url}

#{response.status_line}
Possible reasons:
  - Your openstack_temp_url_key has not been set or is set incorrectly.
  - Swift's proxy server configuration does not include the `tempurl` value in its `pipeline` setting.\n
EOT
    expect(response.status).to be_between(200, 299), error_message

    expect(response.body).to eq('Hello World')
  end

  it 'can list directory contents with each' do
    _, expected_file_key = @resource_tracker.consumes(:simple_blob)
    count = 0
    file_key = nil

    test_directory.files.each do |file|
      file_key = file.key
      count += 1
    end

    expect(count).to eq(1)
    expect(file_key).to eq(expected_file_key)
  end

  it 'can get blob metadata' do
    _, expected_file_key = @resource_tracker.consumes(:simple_blob)
    metadata = test_directory.files.head(expected_file_key).attributes

    expect(metadata).to include({content_type: 'text/plain', key: expected_file_key})
  end

  it 'can download blobs' do
    _, expected_file_key = @resource_tracker.consumes(:simple_blob)
    downloaded_blob = File.join(Dir.mktmpdir, 'test-blob')
    begin
      File.open(downloaded_blob, 'wb') do |file|
        test_directory.files.get(expected_file_key) do |*args|
          file.write(args[0])
        end
      end

      expect(File.read(downloaded_blob)).to eq('Hello World')
    ensure
      FileUtils.rm(downloaded_blob) if downloaded_blob
    end
  end

  it 'can copy blobs' do
    _, original_file_key = @resource_tracker.consumes(:simple_blob)
    root_dir = test_directory
    new_file_key = 'validator-test-blob-copy'
    file = root_dir.files.get(original_file_key)
    expect(root_dir.files.get(new_file_key)).to be_nil

    @resource_tracker.produce(:files, provide_as: :copied_simple_blob) do
      file.copy(root_dir.key, new_file_key)
      [root_dir.key, new_file_key]
    end

    expect(root_dir.files.get(new_file_key)).to_not be_nil
  end

  it 'can delete blobs' do
    _, file_key = @resource_tracker.consumes(:copied_simple_blob)
    files = test_directory.files
    test_blob = files.get(file_key)
    expect(test_blob).to_not be_nil

    test_blob.destroy

    expect(files.get(file_key)).to be_nil
  end

  def test_directory
    directory_key = @resource_tracker.consumes(:root)
    storage.directories.get(directory_key)
  end
end
