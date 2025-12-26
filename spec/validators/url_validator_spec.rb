require 'rails_helper'

RSpec.describe UrlValidator do
  # Setup a dummy model to act as the "Record" to isolates the validator logic from the ShortLink model logic
  let(:dummy_class) do
    Class.new do
      include ActiveModel::Model
      attr_accessor :url

      def self.name
        "TestRecord"
      end
    end
  end

  subject { dummy_class.new }

  # Helper to easily apply the validator with specific options
  def apply_validator(options = {})
    dummy_class.class_eval do
      validates :url, url: options
    end
  end

  describe 'Format Validation' do
    before { apply_validator }

    context 'with valid HTTP/HTTPS URLs' do
      it 'accepts standard http' do
        subject.url = 'http://example.com'
        expect(subject).to be_valid
      end

      it 'accepts standard https' do
        subject.url = 'https://google.com'
        expect(subject).to be_valid
      end

      it 'accepts URLs with paths and query params' do
        subject.url = 'https://example.com/foo/bar?q=1'
        expect(subject).to be_valid
      end

      it 'accepts subdomains' do
        subject.url = 'http://blog.example.com'
        expect(subject).to be_valid
      end
    end

    context 'with invalid schemes' do
      it 'rejects ftp' do
        subject.url = 'ftp://example.com'
        expect(subject).to be_invalid
        expect(subject.errors.added?(:url, :invalid_format)).to be true
      end

      it 'rejects javascript (XSS vector)' do
        subject.url = "javascript:alert('XSS')"
        expect(subject).to be_invalid
        expect(subject.errors.added?(:url, :invalid_format)).to be true
      end

      it 'rejects missing scheme' do
        subject.url = 'google.com'
        expect(subject).to be_invalid
        expect(subject.errors.added?(:url, :invalid_format)).to be true
      end
    end

    context 'with malformed URIs' do
      it 'rejects URLs with spaces (URI.parse fails)' do
        subject.url = 'http://exa mple.com'
        expect(subject).to be_invalid
        expect(subject.errors.added?(:url, :invalid_format)).to be true
      end

      it 'rejects opaque URIs (http:google.com)' do
        # URI::HTTP but host is nil
        subject.url = 'http:google.com'
        expect(subject).to be_invalid
        expect(subject.errors.added?(:url, :invalid_format)).to be true
      end

      it 'rejects empty strings' do
        # Blank is usually handled by `presence: true`, but the validator should handle it gracefully. (valid in the sense that THIS validator has no complaint)
        subject.url = ''
        expect(subject).to be_valid
      end
    end
  end

  describe 'Recursion Validation (no_recursion: true)' do
    before { apply_validator(no_recursion: true) }

    context 'Localhost and Loopback' do
      it 'rejects localhost' do
        subject.url = 'http://localhost:3000/abc'
        expect(subject).to be_invalid
        expect(subject.errors.added?(:url, :recursive_link)).to be true
      end

      it 'rejects 127.0.0.1' do
        subject.url = 'http://127.0.0.1/abc'
        expect(subject).to be_invalid
        expect(subject.errors.added?(:url, :recursive_link)).to be true
      end
    end

    context 'Configured App Host (Dynamic)' do
      it 'rejects the domain defined in ENV["APP_HOST"]' do
        allow(ENV).to receive(:[]).with("APP_HOST").and_return("myshortner.com")

        subject.url = 'https://myshortner.com/some-path'
        expect(subject).to be_invalid
        expect(subject.errors.added?(:url, :recursive_link)).to be true
      end

      it 'rejects the domain even if ENV includes http://' do
        allow(ENV).to receive(:[]).with("APP_HOST").and_return("http://myshortner.com")

        subject.url = 'https://myshortner.com/some-path'
        expect(subject).to be_invalid
        expect(subject.errors.added?(:url, :recursive_link)).to be true
      end

      it 'is case insensitive' do
        allow(ENV).to receive(:[]).with("APP_HOST").and_return("myshortner.com")

        # Uppercase input, lowercase config
        subject.url = 'HTTPS://MYSHORTNER.COM/ABC'
        expect(subject).to be_invalid
        expect(subject.errors.added?(:url, :recursive_link)).to be true
      end
    end

    context 'Valid External Links' do
      it 'accepts other domains' do
        allow(ENV).to receive(:[]).with("APP_HOST").and_return("myshortner.com")

        subject.url = 'https://google.com'
        expect(subject).to be_valid
      end

      it 'accepts links that contain the app host in the path (but not as host)' do
        allow(ENV).to receive(:[]).with("APP_HOST").and_return("myshortner.com")

        subject.url = 'https://google.com/search?q=myshortner.com'
        expect(subject).to be_valid
      end
    end
  end

  describe 'Recursion Validation (Opt-In Check)' do
    context 'when no_recursion option is missing/false' do
      before { apply_validator }

      it 'allows localhost (recursion check is skipped)' do
        subject.url = 'http://localhost:3000'
        expect(subject).to be_valid
      end

      it 'allows the app host' do
        allow(ENV).to receive(:[]).with("APP_HOST").and_return("myshortner.com")

        subject.url = 'http://myshortner.com'
        expect(subject).to be_valid
      end
    end
  end
end
