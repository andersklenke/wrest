# Copyright 2009 Sidu Ponnappa

# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at Http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License 
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and limitations under the License. 
require "rexml/document"
module Wrest #:nodoc:
  module Native #:nodoc:
    # Decorates a response providing support for deserialisation.
    #
    # The following methods are also available (unlisted by rdoc because they're forwarded to Net::HTTP::Response):
    #
    # <tt>:@Http_response,  :code, :message, :body, :Http_version,
    # :[], :content_length, :content_type, :each_header, :each_name, :each_value, :fetch,
    # :get_fields, :key?, :type_params</tt>
    #
    # They behave exactly like their Net::HttpResponse equivalents.
    class Response
      attr_reader :http_response

      extend Forwardable
      def_delegators  :@http_response,  :code, :message, :body, :Http_version,
              :[], :content_length, :content_type, :each_header, :each_name, :each_value, :fetch,
              :get_fields, :key?, :type_params

      # We're overriding :new to act as a factory so
      # we can build the appropriate Response instance based
      # on th response code.
      def self.new(http_response)
        code = http_response.code.to_i
        instance = ((300..303).include?(code) || (305..399).include?(code)  ? Wrest::Native::Redirection : self).allocate
        instance.send :initialize, http_response
        instance
      end

      def initialize(http_response)
        @http_response = http_response
      end

      def initialize_copy(source)
        @headers = source.headers.clone
      end

      # Checks equality between two Wrest::Native::Response objects.
      def ==(other)
        return true if self.equal?(other)
        return false unless other.class == self.class
        return true if self.code == other.code and
            self.headers == other.headers and
            self.http_version == other.http_version and
            self.message == other.message and
            self.body == other.body
      end

      # Return the hash of a Wrest::Native::Response object.
      def hash
        self.code.hash + self.message.hash + self.headers.hash + self.http_version.hash + self.body.hash
      end


      def deserialise(options = {})
        deserialise_using(Wrest::Components::Translators.lookup(@http_response.content_type),options)
      end

      def deserialise_using(translator,options = {})
        translator.deserialise(@http_response,options)
      end

      def headers
        return @headers if @headers

        nethttp_headers_with_string_values=@http_response.to_hash.inject({}) {|new_headers, (old_key, old_value)|
          new_headers[old_key] = old_value.is_a?(Array) ? old_value.join(",") : old_value
          new_headers
          }
        
        @headers=Wrest::HashWithCaseInsensitiveAccess.new(nethttp_headers_with_string_values)

      end

      # A null object implementation - invoking this method on
      # a response simply returns the same response unless
      # the response is Redirection (code 3xx), in which case a
      # get is invoked on the url stored in the response headers
      # under the key 'location' and the new Response is returned.
      def follow(redirect_request_options = {})
        self
      end

      def connection_closed?
        self[Native::StandardHeaders::Connection].downcase == Native::StandardTokens::Close.downcase
      end


      # The functions below deal with Caching.

      def cacheable?
        code_cacheable? && no_cache_flag_not_set? && no_store_flag_not_set? &&
            (not max_age.nil? or (expires_not_in_our_past? && expires_not_in_its_past?)) && pragma_nocache_not_set? &&
            vary_tag_not_set?
      end

      def code_cacheable?
        !code.nil? && ([200, 203, 300, 301, 302, 304, 307].include?(code.to_i))
      end

      def max_age
        return @max_age if @max_age

        max_age  =cache_control_headers.grep(/max-age/)

        @max_age = unless max_age.empty?
                     max_age.first.split('=').last.to_i
                   else
                     nil
                   end
      end

      def no_cache_flag_not_set?
        not cache_control_headers.include?('no-cache')
      end

      def no_store_flag_not_set?
        not cache_control_headers.include?('no-store')
      end

      def pragma_nocache_not_set?
        headers['pragma'].nil? || (not headers['pragma'].include? 'no-cache')
      end

      def vary_tag_not_set?
        headers['vary'].nil?
      end

      def response_date
        return @response_date if @response_date
        @response_date = parse_datefield(headers, "date")
      end


      def expires
        return @expires if @expires
        @expires = parse_datefield(headers, "expires")
      end

      def expires_not_in_our_past?
        if expires.nil?
          false
        else
          expires.to_i > Time.now.to_i
        end
      end

      def expires_not_in_its_past?
        # Invalid header value for Date or Expires means the response is not cacheable
        if  expires.nil? || response_date.nil?
          false
        else
           expires > response_date
        end
      end

      def current_age
        current_time = Time.now.to_i

        # RFC 2616 13.2.3 Age Calculations. TODO: include response_delay in the calculation as defined in RFC. For this, include original Request with Response.
        date_value             = DateTime.parse(headers['date']).to_i rescue current_time
        age_value              = headers['age'].to_i || 0

        apparent_age           = current_time - date_value

        [apparent_age, age_value].max
      end

      def cache_control_headers
        return @cache_control_headers if @cache_control_headers

        @cache_control_headers = headers['cache-control'].split(",").collect {|cc| cc.strip } rescue []
      end

      def freshness_lifetime
        m=max_age
        return m if m

        # Chrome (and I guess Firefox also) uses a heuristic based on (current_time-last_modified_value)/10 as the freshness period if
        # there is no 'Max-Age' or 'Expires' headers. Browsers can afford to be optimistic but we can't.
        # So Wrest uses cached responses if and only if there is a clear expiry/max-age header that validates.
        # The method cacheable? ensures this.

        response_date = DateTime.parse(headers['date']).to_i
        expires_date  = DateTime.parse(headers['expires']).to_i

        return (expires_date - response_date)
      end

      def expired?
        freshness=freshness_lifetime
        if freshness <= 0
          return true
        end

        freshness <= current_age
      end

      def last_modified
        headers['last-modified']
      end

      def can_be_validated?
        not (last_modified.nil? and headers['etag'].nil?)
      end


      # helper function. Used to parse date fields.
      # this function is used and tested by the expires and response_date methods
      def parse_datefield(hash, key)
        if hash[key]
          # Can't trust external input. Do not crash even if invalid dates are passed.
          begin
            DateTime.parse(hash[key].to_s)
          rescue ArgumentError
            nil
          end
        else
          nil
        end
      end

    end
  end
end