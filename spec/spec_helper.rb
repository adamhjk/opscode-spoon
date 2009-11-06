$TESTING=true
$:.push File.join(File.dirname(__FILE__), '..', 'lib')

require 'chef/cookbook_client'
require 'chef/remote_cookbook'
require 'chef/streaming_cookbook_uploader'
