source "http://rubygems.org"

gem 'rake', '~> 13'
gem 'rspec-collection_matchers', '~> 1.2'
gem 'rdoc', '~> 6.2.1'
gem 'simplecov', :platforms => :mri_19

group :multipart_support do
  gem 'multipart-post',  '>= 2.0', '< 3.0'
end

group :nokogiri do
  gem 'nokogiri'
end

group :libxml do
  platforms :ruby do
    gem 'libxml-ruby', '~> 3.2.0' unless Object.const_defined?('RUBY_ENGINE') && RUBY_ENGINE =~ /rbx/
  end
end

group :memcached_support do
  gem 'dalli', '>=2', '<=3.2.2'
end

group :redis_support do
  gem 'redis', '~> 4.2.2'
end

group :eventmachine_support do
  gem 'eventmachine', '~> 1.2.7'
end

gemspec
