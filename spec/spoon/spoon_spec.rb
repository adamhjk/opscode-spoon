#
# Author:: Tim Hinderliter (<tim@opscode.com>)
# Copyright:: Copyright (c) 2009 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.expand_path(File.join(File.dirname(__FILE__), "..", "spec_helper"))

describe "Spoon" do
  LIST_RESPONSE_1 = {
    'cookbook' => 'http://cookbook_uri1',
    'cookbook_maintainer' => 'the_maintainer1',
    'cookbook_name' => 'The Name 1',
    'cookbook_description' => 'The Description 1',
  }
  LIST_RESPONSE_2 = {
    'cookbook' => 'http://cookbook_uri2',
    'cookbook_maintainer' => 'the_maintainer2',
    'cookbook_name' => 'The Name 2',
    'cookbook_description' => 'The Description 2',
  }
  
  before(:each) do
    @mock_rest_client = mock('Opscode::REST')
    Opscode::REST.stub!(:new).and_return(@mock_rest_client)
    
    @cookbook_client = Chef::CookbookClient.new('hostname')
  end

  describe "parsing" do
    it "should parse the json response hash from list-style queries" do
      json_hash = {
        'cookbook' => 'http://cookbook_uri',
        'cookbook_maintainer' => 'the_maintainer',
        'cookbook_name' => 'The Name',
        'cookbook_description' => 'The Description',
      }
      res = Chef::RemoteCookbook.from_json_list(json_hash)
      res.uri.should == 'http://cookbook_uri'
      res.maintainer.should == 'the_maintainer'
      res.name.should == 'The Name'
      res.description.should == 'The Description'
    end

    it "should make a valid url" do
      uri = @cookbook_client.make_uri('api/v1/cookbooks', {'arg1' => 'val1', 'arg2' => 'val2', 'arg?' => 'val&'})

      uri.should == 'http://hostname/api/v1/cookbooks?arg%3F=val%26&arg1=val1&arg2=val2'
    end
  end

  describe "API calls" do
    it "should make a list request and properly handle the result" do
      expected_uri = 'http://hostname/api/v1/cookbooks?items=999999'

      json_result = {
        'items' => [ LIST_RESPONSE_1, LIST_RESPONSE_2 ]
      }

      @mock_rest_client.should_receive(:get).with(expected_uri).once.and_return(json_result)
      res = @cookbook_client.do_list
      res.length.should == 2
    
      first_res = res[0]
      first_res.uri.should == 'http://cookbook_uri1'
      first_res.maintainer.should == 'the_maintainer1'
      first_res.name.should == 'The Name 1'
      first_res.description.should == 'The Description 1'
    
      second_res = res[1]
      second_res.uri.should == 'http://cookbook_uri2'
      second_res.maintainer.should == 'the_maintainer2'
      second_res.name.should == 'The Name 2'
      second_res.description.should == 'The Description 2'
    end
  
    it "should make a search request" do
      expected_uri = 'http://hostname/api/v1/search?q=test+term'
    
      json_result = {
        'items' => [ LIST_RESPONSE_1, LIST_RESPONSE_2 ]
      }
    
      @mock_rest_client.should_receive(:get).with(expected_uri).once.and_return(json_result)
      res = @cookbook_client.do_search('test term')
      res.length.should == 2
    end
  
    it "should throw an exception if items isn't an array" do
      json_result = {} # no 'items' there
      @mock_rest_client.should_receive(:get).and_return(json_result)
      proc { @cookbook_client.do_list }.should raise_error(Exception)
    
      json_result = {
        'items' => {}  # should be an Array
      }
      @mock_rest_client.should_receive(:get).and_return(json_result)
      proc { @cookbook_client.do_list }.should raise_error(Exception)
    end
  
    it "should make a details request and properly handle the result" do
      expected_cookbook_uri = 'http://hostname/api/v1/cookbooks/example'
      expected_version1_uri = 'http://hostname/api/v1/cookbooks/example/0_7_0'
      expected_version2_uri = 'http://hostname/api/v1/cookbooks/example/0_8_0'
      json_result_cookbook = {
        'name' => 'Example',
        'maintainer' => 'timh',
        'description' => 'A Description',
        'versions' => [
          expected_version1_uri,
          expected_version2_uri,
        ],
        'latest_version' => expected_version1_uri,
      }
      json_result_version1 = { 'file' => '/files/example-0.7.0.tar.gz' }
      json_result_version2 = { 'file' => '/files/example-0.8.0.tar.gz' }
    
      @mock_rest_client.should_receive(:get).with(expected_cookbook_uri).and_return(json_result_cookbook)
      @mock_rest_client.should_receive(:get).with(expected_version1_uri).and_return(json_result_version1)
      @mock_rest_client.should_receive(:get).with(expected_version2_uri).and_return(json_result_version2)

      res = @cookbook_client.do_details 'example'
      res.name.should == 'Example'
      res.maintainer.should == 'timh'
      res.description.should == 'A Description'
      res.versions.length.should == 2
    
      version1 = res.versions[0]
      version1.should == res.latest_version
      version1.version.should == '0.7.0'
      version1.tarball_uri.should == 'http://hostname/files/example-0.7.0.tar.gz'
    
      version2 = res.versions[1]
      version2.version.should == '0.8.0'
      version2.tarball_uri.should == 'http://hostname/files/example-0.8.0.tar.gz'
    end
  end
  
  describe "download API" do
    def setup_download_test
      # Download starts out the same as details, because it calls do_details as its
      # first step, to gather information about the cookbook.
      expected_cookbook_uri = 'http://hostname/api/v1/cookbooks/example'
      expected_version1_uri = 'http://hostname/api/v1/cookbooks/example/0_7_0'
      expected_version2_uri = 'http://hostname/api/v1/cookbooks/example/0_8_0'
      json_result_cookbook = {
        'name' => 'Example',
        'maintainer' => 'timh',
        'description' => 'A Description',
        'versions' => [
          expected_version1_uri,
          expected_version2_uri,
        ],
        'latest_version' => expected_version1_uri,
      }
      json_result_version1 = { 'file' => '/files/example-0.7.0.tar.gz' }
      json_result_version2 = { 'file' => 'https://https-example.org/https-files/example-0.8.0.tar.gz' }
    
      @mock_rest_client.should_receive(:get).with(expected_cookbook_uri).and_return(json_result_cookbook)
      @mock_rest_client.should_receive(:get).with(expected_version1_uri).and_return(json_result_version1)
      @mock_rest_client.should_receive(:get).with(expected_version2_uri).and_return(json_result_version2)
    end
    
    it "should download a tarball via HTTP" do
      setup_download_test

      mock_http = mock('Net::HTTP')
      mock_response = mock('Net::HTTPResponse')
      Net::HTTP.stub!(:new).with('hostname', 80).and_return(mock_http)

      mock_http.should_receive(:request_get).with('/files/example-0.7.0.tar.gz').and_return(mock_response)
      mock_response.should_receive(:body).and_return('contents')

      mock_file = mock("File")
      File.stub!(:open).and_return(mock_file)
      mock_file.should_receive(:write).with('contents')
      mock_file.should_receive(:close)
      
      @cookbook_client.do_download 'example'
    end
    
    it "should download a versioned tarball via HTTPS" do
      setup_download_test

      mock_http = mock('Net::HTTP')
      mock_response = mock('Net::HTTPResponse')
      Net::HTTP.stub!(:new).with('https-example.org', 443).and_return(mock_http)

      mock_http.should_receive(:use_ssl=).with(true)
      mock_http.should_receive(:verify_mode=)
      mock_http.should_receive(:request_get).with('/https-files/example-0.8.0.tar.gz').and_return(mock_response)
      mock_response.should_receive(:body).and_return('contents')

      mock_file = mock("File")
      File.stub!(:open).and_return(mock_file)
      mock_file.should_receive(:write).with('contents')
      mock_file.should_receive(:close)
      
      @cookbook_client.do_download 'example', '0.8.0'
    end
    
    it "should throw an exception when a non-existant version is requested" do
      setup_download_test

      proc { @cookbook_client.do_download 'example', '2.0.0' }.should raise_error(Exception)
    end
    
  end
  
  describe "RemoteCookbookVersion" do
    it "should handle relative tarball paths" do
      cookbook_version = Chef::RemoteCookbookVersion.new('http://hostname/api/v1/cookbooks/example/0_7_0')
      cookbook_version.set_from_json_hash('hostname', { 'file' => '/server/path_to/example-0.7.0.tar.gz' })
      
      cookbook_version.tarball_uri.should == 'http://hostname/server/path_to/example-0.7.0.tar.gz'
    end

    it "should handle absolute tarball paths" do
      cookbook_version = Chef::RemoteCookbookVersion.new('http://hostname/api/v1/cookbooks/example/0_7_0')
      cookbook_version.set_from_json_hash('hostname', { 'file' => 'http://other_server/path_to/example-0.7.0.tar.gz' })
      
      cookbook_version.tarball_uri.should == 'http://other_server/path_to/example-0.7.0.tar.gz'
    end
  end
  
end


