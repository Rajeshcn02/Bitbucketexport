# frozen_string_literal: true

require "spec_helper"

describe BitbucketServer::Connection do
  subject(:connection) do
    described_class.new(
      base_url:     "https://example.com",
      user:         "unit-test",
      password:     "hackme",

      open_timeout: 30,
      read_timeout: 300,
      retries:      5,
      ssl_verify:   false
    )
  end

  context "when Faraday options are set" do
    subject(:faraday) { connection.faraday }

    it "sets open timeout" do
      expect(faraday.options.open_timeout).to eq(30)
    end

    it "sets read timeout" do
      expect(faraday.options.timeout).to eq(300)
    end

    it "adds a Faraday::Request::Retry handler" do
      expect(faraday.builder.handlers).to include(Faraday::Request::Retry)
    end

    it "disables SSL verification" do
      expect(faraday.ssl.verify?).to be_falsey
    end
  end

  context "when Faraday options are not set" do
    subject(:faraday) do
      described_class.new(
        base_url: "https://example.com",
        user:     "unit-test",
        password: "hackme"
      ).faraday
    end

    let(:defaults) do
      Faraday.default_connection_options.request
    end

    it "uses default open timeout" do
      expect(faraday.options.open_timeout).to eq(defaults.open_timeout)
    end

    it "uses default read timeout" do
      expect(faraday.options.timeout).to eq(defaults.timeout)
    end

    it "does not add a Faraday::Request::Retry handler" do
      expect(faraday.builder.handlers).to_not include(Faraday::Request::Retry)
    end

    it "enforces SSL verification" do
      expect(faraday.ssl.verify?).to be_truthy
    end
  end

  describe "#initialize" do
    context "with a valid URL, username, and password" do
      subject(:connection) do
        described_class.new(
          base_url:     "https://example.com",
          user:         "unit-test",
          password:     "hackme"
        )
      end

      it "can specify records per page" do
        url = connection.encode_url(
          path: %w(some path),
          query: {
            limit: 1000
          }
        )

        expect(url).to eq(
          "https://example.com/rest/api/1.0/some/path?limit=1000"
        )
      end

      it "can specify which page to fetch" do
        url = connection.encode_url(
          path: %w(some path),
          query: {
            start: 25
          }
        )

        expect(url).to eq("https://example.com/rest/api/1.0/some/path?start=25")
      end

      it "can specify records per page and which page to fetch" do
        url = connection.encode_url(
          path: %w(some path),
          query: {
            limit: 1000,
            start: 25
          }
        )

        expect(url).to eq(
          "https://example.com/rest/api/1.0/some/path?limit=1000&start=25"
        )
      end
    end

    context "with a bad URL" do
      let(:bad_url) { "ssh://example.com" }

      subject(:connection) do
        described_class.new(
          base_url: bad_url,
          user:     "unit-test",
          password: "hackme"
        )
      end

      it "raises BitbucketServer::Connection::InvalidBaseUrl" do
        expect { subject }.to raise_error(
          BitbucketServer::Connection::InvalidBaseUrl,
          "#{bad_url} is not a valid URL!"
        )
      end
    end
  end

  describe "#inspect" do
    context "when using basic authentication" do
      subject(:connection) do
        described_class.new(
          base_url: "https://example.com",
          user:     "unit-test",
          password: "hackme"
        )
      end

      it "masks password on inspect" do
        inspected = subject.inspect
        expect(inspected).not_to include("hackme")
        expect(inspected).to include("@password=\"*******\"")
      end
    end

    context "when using token authentication" do
      subject(:connection) do
        described_class.new(
          base_url: "https://example.com",
          user:     "unit-test",
          token:    "123456"
        )
      end

      it "masks token on inspect" do
        inspected = subject.inspect
        expect(inspected).not_to include("123456")
        expect(inspected).to include("@token=\"*******\"")
      end
    end
  end

  describe "#faraday" do
    context "when user is provided but token and password are not" do
      subject(:faraday) do
        described_class.new(
          base_url: "https://example.com",
          user:     "unit-test"
        ).faraday
      end

      it "raises BitbucketServer::Connection::MissingCredentialsError" do
        expect { faraday }.to raise_error(
          BitbucketServer::Connection::MissingCredentialsError
        )
      end
    end

    context "when password is provided but user is not" do
      subject(:faraday) do
        described_class.new(
          base_url: "https://example.com",
          password: "examplepassword"
        ).faraday
      end

      it "raises BitbucketServer::Connection::MissingCredentialsError" do
        expect { faraday }.to raise_error(
          BitbucketServer::Connection::MissingCredentialsError
        )
      end
    end

    context "when token is provided but user and password is not" do
      subject(:faraday) do
        described_class.new(
          base_url: "https://example.com",
          token:    "exampletoken"
        ).faraday
      end

      it "returns a Faraday::Connection" do
        expect(faraday).to be_a(Faraday::Connection)
      end
    end
  end

  describe "#faraday_safe" do
    let(:project_model) do
      bitbucket_server.project_model("doesnt-exist")
    end

    let(:project_404) do
      VCR.use_cassette("projects/doesnt-exist") do
        begin
          url = bitbucket_server.connection.encode_url(path: project_model.path)
          bitbucket_server.connection.faraday.get(url)
        rescue Faraday::ResourceNotFound => exception
          exception
        end
      end
    end

    it "calls #faraday with the faraday_method param" do
      expect(connection.faraday).to receive(:get).with(
        "https://example.com"
      )

      connection.faraday_safe(:get, "https://example.com")
    end

    it "raises Faraday::ConnectionFailed with exception message" do
      expect(connection.faraday).to receive(:get).and_raise(
        Faraday::ConnectionFailed, "message"
      )

      expect {
        connection.faraday_safe(:get, "https://example.com")
      }.to raise_error(Faraday::ConnectionFailed, "message")
    end

    it "raises Faraday::TimeoutError with retry count and URL" do
      expect(connection.faraday).to receive(:get).and_raise(
        Faraday::TimeoutError
      )

      expect {
        connection.faraday_safe(:get, "https://example.com")
      }.to raise_error(
        Faraday::TimeoutError,
        "Timed out 5 times during GETs to https://example.com"
      )
    end

    it "raises Faraday::ClientError with a message" do
      allow(connection.faraday).to receive(:get).with(
        "https://example.com/rest/api/1.0/projects/doesnt-exist"
      ).and_raise(project_404)

      expect {
        connection.faraday_safe(
          :get,
          "https://example.com/rest/api/1.0/projects/doesnt-exist"
        )
      }.to raise_error do |exception|
        expect(exception.message).to eq(
          "404 on GET to https://example.com/rest/api/1.0/projects/" \
          "doesnt-exist: Project doesnt-exist does not exist."
        )
      end
    end

    it "calls #around_request" do
      test_double = double("TestDouble")

      connection.around_request = proc do |faraday_method, url, &request|
        test_double.faraday_method(faraday_method)
        test_double.url(url)

        request.call
      end

      expect(test_double).to receive(:faraday_method).with(:get)
      expect(test_double).to receive(:url).with("https://example.com")

      expect(connection.faraday).to receive(:get)

      connection.faraday_safe(:get, "https://example.com")
    end
  end
end
