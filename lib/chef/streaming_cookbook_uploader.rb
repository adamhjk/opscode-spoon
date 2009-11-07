require 'rubygems'
require 'net/http'
require 'mixlib/authentication/signedheaderauth'
require 'openssl'

# inspired by/cargo-culted from http://stanislavvitvitskiy.blogspot.com/2008/12/multipart-post-in-ruby.html
module Chef
  class StreamingCookbookUploader
    DefaultHeaders = { 'accept' => 'application/json' }

    def post(to_url, user_id, secret_key_filename, params = {}, headers = {})
      make_request(:post, to_url, user_id, secret_key_filename, params, headers)
    end

    def put(to_url, user_id, secret_key_filename, params = {}, headers = {})
      make_request(:put, to_url, user_id, secret_key_filename, params, headers)
    end

    def make_request(http_verb, to_url, user_id, secret_key_filename, params = {}, headers = {})
      boundary = '----RubyMultipartClient' + rand(1000000).to_s + 'ZZZZZ'
      parts = []
      content_file = nil
      content_body = nil

      timestamp = Time.now.utc.iso8601
      secret_key = OpenSSL::PKey::RSA.new(File.read(secret_key_filename))

      unless params.nil? || params.empty?
        params.each do |key, value|
          if value.kind_of?(File)
            content_file = value
            filepath = value.path
            filename = File.basename(filepath)
            parts << StringPart.new( "--" + boundary + "\r\n" +
            "Content-Disposition: form-data; name=\"" + key.to_s + "\"; filename=\"" + filename + "\"\r\n" +
            "Content-Type: application/octet-stream\r\n\r\n")
            parts << StreamPart.new(value, File.size(filepath))
            parts << StringPart.new("\r\n")
          else
            content_body = value.to_s
            parts << StringPart.new( "--" + boundary + "\r\n" +
            "Content-Disposition: form-data; name=\"" + key.to_s + "\"\r\n\r\n")
            parts << StringPart.new(content_body + "\r\n")
          end
        end
        parts << StringPart.new("--" + boundary + "--\r\n")
      end

      body_stream = MultipartStream.new(parts)

      timestamp = Time.now.utc.iso8601

      signing_options = {
        :http_method=>http_verb,
        :user_id=>user_id,
        :timestamp=>timestamp
      }
      (content_file && signing_options[:file] = content_file) || (signing_options[:body] = (content_body || ""))

      headers.merge!(Mixlib::Authentication::SignedHeaderAuth.signing_object(signing_options).sign(secret_key))

      content_file.rewind if content_file

      # net/http doesn't like symbols for header keys, so we'll to_s each one just in case
      headers = DefaultHeaders.merge(Hash[*headers.map{ |k,v| [k.to_s, v] }.flatten])

      url = URI.parse(to_url)
      req = case http_verb
      when :put
        Net::HTTP::Put.new(url.path, headers)
      when :post
        Net::HTTP::Post.new(url.path, headers)
      end              
      req.content_length = body_stream.size
      req.content_type = 'multipart/form-data; boundary=' + boundary unless parts.empty?
      req.body_stream = body_stream

      http = Net::HTTP.new(url.host, url.port)
      if url.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      res = http.request(req)
      #res = http.start {|http_proc| http_proc.request(req) }

      # alias status to code and to_s to body for test purposes
      # TODO: stop the following madness!
      class << res
        alias :to_s :body

        # BUGBUG this makes the response compatible with what respsonse_steps expects to test headers (response.headers[] -> response[])
        def headers
          self
        end

        def status
          code.to_i
        end
      end
      res
    end
  end

  class StreamPart
    def initialize(stream, size)
      @stream, @size = stream, size
    end

    def size
      @size
    end

    # read the specified amount from the stream
    def read(offset, how_much)
      @stream.read(how_much)
    end
  end

  class StringPart
    def initialize(str)
      @str = str
    end

    def size
      @str.length
    end

    # read the specified amount from the string startiung at the offset
    def read(offset, how_much)
      @str[offset, how_much]
    end
  end

  class MultipartStream
    def initialize(parts)
      @parts = parts
      @part_no = 0
      @part_offset = 0
    end

    def size
      @parts.inject(0) {|size, part| size + part.size}
    end

    def read(how_much)
      return nil if @part_no >= @parts.size

      how_much_current_part = @parts[@part_no].size - @part_offset

      how_much_current_part = if how_much_current_part > how_much
        how_much
      else
        how_much_current_part
      end

      how_much_next_part = how_much - how_much_current_part

      current_part = @parts[@part_no].read(@part_offset, how_much_current_part)

      # recurse into the next part if the current one was not large enough
      if how_much_next_part > 0
        @part_no += 1
        @part_offset = 0
        next_part = read(how_much_next_part)
        current_part + if next_part
          next_part
        else
          ''
        end
      else
        @part_offset += how_much_current_part
        current_part
      end
    end
  end

end
