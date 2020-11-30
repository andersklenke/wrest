require "spec_helper"
require 'rspec'

Wrest::Caching.enable_memcached

describe Wrest::Caching do
  context "functional", :functional => true do
    before :each do

      @memcached = Wrest::Caching::Memcached.new
      @memcached["abc"]="xyz"
    end

    context "initialization defaults" do
      it "should always default the list of server urls to nil" do
        Dalli::Client.should_receive(:new).with(nil, {})
        client = Wrest::Caching::Memcached.new
      end

      it "should always default the options to an empty hash" do
        Dalli::Client.should_receive(:new).with(nil, {})
        client = Wrest::Caching::Memcached.new
      end
    end

    it "should know how to retrieve a cache entry" do
      expect(@memcached["abc"]).to eq("xyz")
    end

    it "should know how to update a cache entry" do
      @memcached["abc"] = "123"
      expect(@memcached["abc"]).to eq("123")
    end

    it "should know how to delete a cache entry" do
      @memcached.delete("abc").should == "xyz"
      expect(@memcached["abc"]).to eq(nil)
    end

    context "when a Dalli runtime exception is thrown" do
      before :each do
        allow_any_instance_of(Dalli::Client)
          .to receive(:get)
          .and_raise(Dalli::RingError, 'No server available')

        allow_any_instance_of(Dalli::Client)
          .to receive(:set)
          .and_raise(Dalli::RingError, 'No server available')

        allow_any_instance_of(Dalli::Client)
          .to receive(:delete)
          .and_raise(Dalli::RingError, 'No server available')

        @failing_memcached = Wrest::Caching::Memcached.new
      end

      it "should treat get as a cache miss" do
        @failing_memcached = Wrest::Caching::Memcached.new
        expect(@failing_memcached["abc"]).to eq(nil)
      end

      it "should treat put as a cache miss" do
        @failing_memcached["abc"] = "123"
        expect(@failing_memcached["abc"]).to eq(nil)
      end

      it "should treat delete as a cache miss" do
        @failing_memcached.delete("abc").should == nil
        expect(@failing_memcached["abc"]).to eq(nil)
      end
    end
  end
end

