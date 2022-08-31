begin
  gem 'dalli', '<=3.2.1', '>=2'
rescue Gem::LoadError => e
  Wrest.logger.debug "Matching Dalli version not found must be between 2 an 3.2.1. The Dalli gem is necessary to use the memcached caching back-end."
  raise e
end

require 'dalli'

module Wrest::Caching
  class Memcached

    def initialize(server_urls=nil, options={})
      @memcached = Dalli::Client.new(server_urls, options)
    end

    def [](key)
      begin
        @memcached.get(key)
      rescue Dalli::DalliError => e
        Wrest.logger.error "Error reading #{key} from cache: #{e.inspect}"
        return nil
      end
    end

    def []=(key, value)
      begin
        @memcached.set(key, value)
      rescue Dalli::DalliError => e
        Wrest.logger.error "Error writing #{key} to cache: #{e.inspect}"
        return nil
      end
    end

    # should be compatible with Hash - return value of the deleted element.
    def delete(key)
      begin
        value = self[key]

        @memcached.delete key

        return value
      rescue Dalli::DalliError => e
        Wrest.logger.error "Error deleting #{key} from cache: #{e.inspect}"
        return nil
      end
    end
  end
end
