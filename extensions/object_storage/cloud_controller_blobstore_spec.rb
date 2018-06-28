require 'fileutils'
require 'securerandom'

describe 'Cloud Controller using Swift as blobstore', cpi_api: true do
  let(:storage) {
    storage_config = {:openstack_temp_url_key => Validator::Api.configuration.extensions['object_storage']['openstack']['openstack_temp_url_key']}
    Validator::Api::FogOpenStack.storage(storage_config)
  }

  before(:all) do
    @resource_tracker = Validator::Api::ResourceTracker.create
    @validator_dirname = "validator-key-#{SecureRandom.uuid}"
  end

  it 'can create a directory' do
    directory_id = Validator::Api::FogOpenStack.with_openstack('Directory could not be created') do
      @resource_tracker.produce(:directories, provide_as: :root) {
        root = storage.directories.create({
            key: @validator_dirname,
            public: false
        })
        wait_for_swift
        root.key
      }
    end

    expect(directory_id).to_not be_nil
  end

  it 'can get a directory' do
    expect(test_directory.key).to eq(@validator_dirname)
  end

  it 'can upload a blob' do
    directory = test_directory
    expect{
      Validator::Api::FogOpenStack.with_openstack('Blob could not be uploaded') do
        @resource_tracker.produce(:files, provide_as: :simple_blob) do
          file = directory.files.create({
            key: 'validator-test-blob',
            body: 'Hello World',
            content_type: 'text/plain',
            public: false
          })
          wait_for_swift
          [directory.key, file.key]
        end
      end
    }.not_to raise_error
  end

  it 'can create a temporary url' do
    _, file_key = @resource_tracker.consumes(:simple_blob)
    root_dir = test_directory

    file = Validator::Api::FogOpenStack.with_openstack('Blob could not be downloaded') do
      root_dir.files.get(file_key)
    end

    url = Validator::Api::FogOpenStack.with_openstack('Temporary URL could not be created') do
      file.url(Time.now.utc + 360000)
    end

    expect(url).to_not be_nil

    response = Validator::Api::FogOpenStack.with_openstack('Temporary URL could not be accessed') do
      Excon.get(url, configure_ssl_options)
    end
    error_message = <<EOT
Unable to access the tempurl:
#{url}

#{response.status_line}
Possible reasons:
  - You didn't set an X-Account-Meta-Temp-URL-Key for your Swift account
  - The configured openstack_temp_url_key doesn't match the X-Account-Meta-Temp-URL-Key
  - Swift's proxy server configuration does not include the `tempurl` value in its `pipeline` setting.\n
EOT
    expect(response.status).to be_between(200, 299), error_message

    expect(response.body).to eq('Hello World')
  end

  it 'can list directory contents with each' do
    _, expected_file_key = @resource_tracker.consumes(:simple_blob)
    count = 0
    file_key = nil

    Validator::Api::FogOpenStack.with_openstack('Directory content could not be listed ') do
      test_directory.files.each do |file|
        file_key = file.key
        count += 1
      end
    end

    expect(count).to eq(1)
    expect(file_key).to eq(expected_file_key)
  end

  it 'can get blob metadata' do
    _, expected_file_key = @resource_tracker.consumes(:simple_blob)
    metadata = Validator::Api::FogOpenStack.with_openstack('Blob metadata could not be retrieved') do
      test_directory.files.head(expected_file_key).attributes
    end

    expect(metadata).to include({content_type: 'text/plain', key: expected_file_key})
  end

  it 'can download blobs' do
    _, expected_file_key = @resource_tracker.consumes(:simple_blob)
    downloaded_blob = File.join(Dir.mktmpdir, 'test-blob')
    begin
      File.open(downloaded_blob, 'wb') do |file|
        Validator::Api::FogOpenStack.with_openstack('Blob could not be downloaded') do
          test_directory.files.get(expected_file_key) do |*args|
            file.write(args[0])
          end
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
    original_file, new_file = Validator::Api::FogOpenStack.with_openstack('Blob could not be downloaded') do
      original_file = root_dir.files.get(original_file_key)
      new_file = root_dir.files.get(new_file_key)
      [original_file, new_file]
    end
    expect(new_file).to be_nil

    Validator::Api::FogOpenStack.with_openstack('Blob could not be copied') do
      @resource_tracker.produce(:files, provide_as: :copied_simple_blob) do
        original_file.copy(root_dir.key, new_file_key)
        wait_for_swift
        [root_dir.key, new_file_key]
      end
    end

    new_file = Validator::Api::FogOpenStack.with_openstack('Blob could not be downloaded') do
      root_dir.files.get(new_file_key)
    end
    expect(new_file).to_not be_nil
  end

  it 'can delete blobs' do
    _, file_key = @resource_tracker.consumes(:copied_simple_blob)
    files = test_directory.files
    test_blob = Validator::Api::FogOpenStack.with_openstack('Blob could not be downloaded') do
      files.get(file_key)
    end
    expect(test_blob).to_not be_nil

    Validator::Api::FogOpenStack.with_openstack('Blob could not be deleted') do
      test_blob.destroy
    end
    wait_for_swift

    deleted_file = Validator::Api::FogOpenStack.with_openstack('Blob could not be downloaded') do
      files.get(file_key)
    end
    expect(deleted_file).to be_nil
  end

  def wait_for_swift
    seconds = Validator::Api.configuration.extensions['object_storage']['openstack']['wait_for_swift'] || 5
    sleep seconds
  end

  def test_directory
    directory_key = @resource_tracker.consumes(:root)
    Validator::Api::FogOpenStack.with_openstack('Directory could not be accessed') do
      storage.directories.get(directory_key)
    end
  end

  def configure_ssl_options
    options = {}
    if Validator::Api.configuration.openstack['connection_options'].fetch('ssl_verify_peer', true).to_s == 'true'
      options[:ssl_ca_file] = Validator::Api.configuration.openstack['connection_options']['ssl_ca_file']
    else
      options[:ssl_verify_peer] = false
    end
    options
  end
end
