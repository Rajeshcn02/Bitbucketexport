# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer::Model do
  subject(:model) { described_class.new }

  shared_examples "a method that calls #request" do |request_method|
    let(:connection) { double }

    before do
      allow(model).to receive(:connection).and_return(connection)
    end

    it "omits nil query params" do
      expect(connection).to receive(request_method).with(
        "https://example.com/activities", query: { foo: "bar" }
      )

      model.send(
        request_method,
        "activities",
        base_path: "https://example.com",
        query: { foo: "bar", baz: nil }
      )
    end

    it "does not pass query param when all query values are empty" do
      expect(connection).to receive(request_method).with(
        "https://example.com/activities", {}
      )

      model.send(
        request_method,
        "activities",
        base_path: "https://example.com",
        query: { foo: nil, bar: nil }
      )
    end
  end

  describe "#get" do
    include_examples "a method that calls #request", :get
  end

  describe "#head" do
    include_examples "a method that calls #request", :head
  end
end
