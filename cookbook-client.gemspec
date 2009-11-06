# Generated by jeweler
# DO NOT EDIT THIS FILE
# Instead, edit Jeweler::Tasks in Rakefile, and run `rake gemspec`
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{cookbook-client}
  s.version = "0.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Opscode, Inc."]
  s.date = %q{2009-11-06}
  s.default_executable = %q{spoon}
  s.email = %q{info@opscode.com}
  s.executables = ["spoon"]
  s.files = [
    "NOTICE",
     "Rakefile",
     "VERSION",
     "bin/spoon",
     "lib/chef/cookbook_client.rb",
     "lib/chef/remote_cookbook.rb",
     "lib/chef/streaming_cookbook_uploader.rb",
     "spec/spec.opts",
     "spec/spec_helper.rb",
     "spec/spoon/spoon_spec.rb"
  ]
  s.has_rdoc = true
  s.homepage = %q{http://www.opscode.com}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{A command-line tool for interacting with the Cookbook Community Site, cookbooks.opscode.com}
  s.test_files = [
    "spec/spec_helper.rb",
     "spec/spoon/spoon_spec.rb",
     "examples/couchdb/metadata.rb",
     "examples/couchdb/recipes/default.rb",
     "examples/couchdb2/metadata.rb",
     "examples/couchdb2/recipes/default.rb",
     "examples/couchdb3/metadata.rb",
     "examples/couchdb3/recipes/default.rb",
     "examples/couchdb4/metadata.rb",
     "examples/couchdb4/recipes/default.rb",
     "examples/couchdb5/metadata.rb",
     "examples/couchdb5/recipes/default.rb",
     "examples/rest-delete.rb",
     "examples/test-auth-against-erlang.rb",
     "examples/test-hash-find.rb",
     "examples/test-ssl.rb",
     "examples/test-using-restclient-multipart.rb",
     "examples/test_signature_verification.rb",
     "examples/testrestoc.rb",
     "examples/upload-using-cw_multipart.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<mixlib-authentication>, [">= 0"])
    else
      s.add_dependency(%q<mixlib-authentication>, [">= 0"])
    end
  else
    s.add_dependency(%q<mixlib-authentication>, [">= 0"])
  end
end
