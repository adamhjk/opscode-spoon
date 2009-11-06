
require 'chef/streaming_cookbook_uploader'
require 'chef/remote_cookbook'
require 'opscode/rest'
require 'cgi'

module Chef
  class CookbookClient
    def initialize(hostname)
      @hostname = hostname
      @client = Opscode::REST.new
    end

    def do_search(term)
      uri = make_uri('api/v1/search', {'q' => term})
      parse_json_cookbook_list @client.get(uri)
    end

    def do_list()
      params = {}
      params['items'] = 999999

      uri = make_uri('api/v1/cookbooks', params)

      parse_json_cookbook_list @client.get(uri)
    end

    # parse json output back from pivotallabs. assumes a hash comes back, which
    # contains a key 'items', which itself is an array. that array has cookbook
    # hashes in it.
    # e.g. http://opscode-community.pivotallabs.com/api/v1/cookbooks/
    def parse_json_cookbook_list(json_hash)
      cookbooks_res = []

      items = json_hash['items']
      if !items.nil? && items.kind_of?(Array)
        items.each do |item|
          cookbook = RemoteCookbook.from_json_list(item)

          cookbooks_res.push cookbook
        end
      else
        raise Exception, "items should be an Array, but it's #{items}"
      end
      cookbooks_res
    end

    # Retrieve details and an enumeration of versions for the given cookbook.
    def do_details(cookbook_name)
      cookbook_uri = make_uri "api/v1/cookbooks/#{cookbook_name}"

      json_hash = @client.get(cookbook_uri)

      cookbook_res = RemoteCookbook.from_json_details(cookbook_uri, json_hash)
      cookbook_res.versions.each do |ver|
        ver_json_hash = @client.get(ver.uri)

        # populate additional fields of the version object with the result
        # from the versioned JSON call.
        ver.set_from_json_hash @hostname, ver_json_hash
      end

      cookbook_res
    end

    # Download the tarball for a given cookbook. If the version isn't specified,
    # grab the latest. Returns the file
    def do_download(cookbook_name, cookbook_version = nil)
      # Fetch the details of the cookbook we're about to download, so we can
      # look at its versions. If there's no such cookbook, rest client will
      # throw an exception.
      remote_cookbook = do_details cookbook_name

      # if user specified a version, look it up, otherwise use the latest.
      found_version = 
      if cookbook_version
        remote_cookbook.find_version_by_user_version(cookbook_version)
      else
        remote_cookbook.latest_version
      end

      # Download the cookbook if we were able to find a valid version.
      if found_version
        if found_version.tarball_uri =~ /.*\/([^\/]+)$/
          out_filename = $1
        end
        if out_filename.nil?
          raise ArgumentError, "do_download: can't figure out the filename pattern for #{found_version.tarball_uri}"
        end

        # TODO: should be using a streaming form, but am using the string all-at-once
        # version for now.
        uri = URI.parse found_version.tarball_uri
        http_client = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == 'https'
          http_client.use_ssl = true
          http_client.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        http_res = http_client.request_get(uri.path)
        out = File.open(out_filename, 'wb')
        out.write(http_res.body)
        out.close

        out_filename
      else
        raise Exception, "No such version of cookbook '#{cookbook_name}': #{cookbook_version}"
      end
    end

    def do_upload(cookbook_filename, cookbook_category, user_id, user_secret_filename)
      cookbook_uploader = StreamingCookbookUploader.new
      uri = make_uri "api/v1/cookbooks"

      category_string = { 'category'=>cookbook_category }.to_json

      http_resp = cookbook_uploader.post(uri, user_id, user_secret_filename, {
        :tarball => File.open(cookbook_filename),
        :cookbook => category_string
      })

      res = JSON.parse(http_resp.body)
      if http_resp.code.to_i != 201
        if !res['error_messages'].nil?
          if res['error_messages'][0] =~ /Version already exists/
            raise "Version already exists"
          else
            raise Exception, res
          end
        else
          raise Exception, "Error uploading: #{res}"
        end
      end

      #puts "do_upload: POST res is #{res}"
      res
    end

    # Delete the given cookbook, using the given credentials
    def do_delete(cookbook_name, user_id, user_secret_filename)
      cookbook_to_delete = do_details(cookbook_name)
      if cookbook_to_delete.nil?
        raise ArgumentError, "No such cookbook to delete #{cookbook_name}"
      end

      user_secret_rsa = OpenSSL::PKey::RSA.new(File.read(user_secret_filename))

      client_options = {
        :authenticate => true,
        :user_id => user_id,
        :user_secret => user_secret_rsa
      }

      # delete the whole cookbook
      @client.request(:delete, cookbook_to_delete.uri, client_options)
    end

    def do_deprecate(cookbook_name, replacement_cookbook_name, user_id, user_secret_filename)
      cookbook_to_deprecate = do_details(cookbook_name)
      if cookbook_to_deprecate.nil?
        raise ArgumentError, "No such cookbook to deprecate #{cookbook_name}"
      end

      user_secret_rsa = OpenSSL::PKey::RSA.new(File.read(user_secret_filename))

      deprecate_uri = "#{cookbook_to_deprecate.uri}/deprecation"
      deprecation_json = { 'replacement_cookbook_name' => replacement_cookbook_name }.to_json

      client_options = {
        :authenticate => true,
        :user_id => user_id,
        :user_secret => user_secret_rsa,
        :payload => deprecation_json,
      }
      
      # delete the whole cookbook
      res = @client.post(deprecate_uri, client_options)
    end

    # make a url given the hostname we were set up with, the base path,
    # and any parameters that were included.
    def make_uri(base, params = {})
      if params && !params.empty?
        path_components = params.each.collect do |key, value| 
          key = CGI.escape(key.to_s)
          value = CGI.escape(value.to_s)
          "#{key}=#{value}"
        end
        path_components_str = '?' + path_components.join('&')
      end
      "http://#{@hostname}/#{base}#{path_components_str}"
    end
  end

end

