
module Opscode
  module Spoon
    class RemoteCookbookVersion
      attr_accessor :uri
      attr_accessor :tarball_uri

      def initialize(uri)
        @uri = uri
      end

      def version
        # http://www.example.com/api/v1/cookbooks/apache/versions/1_0
        version = ""
        if /.+\/([^\/]+)$/ =~ @uri
          version = $1
        end
        version.gsub(/_/, '.')
      end

      def set_from_json_hash(hostname, json_hash)
        tarball_path = json_hash['file']

        if tarball_path =~ /http/
          # absolute path. use it verbatim.
          @tarball_uri = tarball_path
        else
          # relative path. use the hostname we already have and the path in 'file'
          # chop off leading slash for relative paths
          if tarball_path =~ /^\/(.+)$/
            tarball_path = $1
          end

          @tarball_uri = "http://#{hostname}/#{tarball_path}"
        end

        #created_at = Date.parse json_hash['created_at']
        #updated_at = Date.parse json_hash['updated_at']
        #average_rating = json_hash['average_rating']
        #license = json_hash['license']
      end

    end

    class RemoteCookbook
      attr_accessor :uri, :maintainer, :name, :description
      attr_accessor :versions, :latest_version

      def initialize(params = {})
        @uri = params[:uri]
        @maintainer = params[:maintainer]
        @name = params[:name]
        @description = params[:description]

        @versions = Array.new
      end

      # these kind of responses come back from 'search' and 'list'
      def self.from_json_list(json_hash)
        res = new

        res.uri = json_hash['cookbook']
        res.maintainer = json_hash['cookbook_maintainer']
        res.name = json_hash['cookbook_name']
        res.description = json_hash['cookbook_description']

        res
      end

      # this type of response comes back from directly looking up a cookbook
      def self.from_json_details(uri, json_hash)
        unless json_hash.kind_of?(Hash)
          raise "from_json_show needs a hash"
        end

        res = new

        res.uri = uri
        res.name = json_hash['name']
        res.maintainer = json_hash['maintainer']
        res.description = json_hash['description']
        # res.external_url = json_hash['external_url']
        # res.category = json_hash['category']
        # res.average_rating = json_hash['average_rating']
        # res.created_at = Date.parse json_hash['created_at']
        # res.updated_at = Date.parse json_hash['updated_at']

        versions = json_hash['versions']
        if (!versions.nil?) && (versions.kind_of? Array)
          versions.each do |ver|
            res.versions.push(RemoteCookbookVersion.new ver)
          end
          res.latest_version = res.find_version_by_uri json_hash['latest_version']
        end

        res
      end

      def find_version_by_uri(uri)
        @versions.find { |ver| ver.uri == uri }
      end

      def find_version_by_user_version(version)
        @versions.find { |ver| ver.version == version }
      end

      def to_s
        "RemoteCookbook #{@name}: description '#{@description}', maint #{@maintainer}, uri #{@uri}"
      end

    end
  end
  
end
