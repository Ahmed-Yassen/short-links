require 'rails_helper'

RSpec.describe ShortLink, type: :model do
  let(:valid_url) { "https://www.google.com/search?q=rspec" }

  describe "Validations" do
    # Use a new instance for validation tests
    subject { described_class.new(original_url: valid_url) }

    context "Presence" do
      it "is valid with a valid URL" do
        expect(subject).to be_valid
      end

      it "is invalid without an original_url" do
        subject.original_url = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:original_url]).to include("can't be blank")
      end
    end

    context "Recursive Shortening Prevention" do
      let(:recursion_error) { I18n.t('activerecord.errors.models.short_link.attributes.original_url.recursive_link') }

      it "rejects localhost URLs" do
        subject.original_url = "http://localhost/foo"
        expect(subject).not_to be_valid
        expect(subject.errors[:original_url]).to include(recursion_error)
      end

      it "rejects 127.0.0.1 IPs" do
        subject.original_url = "http://127.0.0.1/foo"
        expect(subject).not_to be_valid
        expect(subject.errors[:original_url]).to include(recursion_error)
      end

      context "when configured with a production domain" do
        before do
          allow(ENV).to receive(:[]).with("APP_HOST").and_return("myshortner.com")
        end

        it "rejects URLs matching the APP_HOST" do
          subject.original_url = "https://myshortner.com/recursion"
          expect(subject).not_to be_valid
          expect(subject.errors[:original_url]).to include(recursion_error)
        end
      end
    end

    context "URL Validator Integration" do
      it "rejects malformed schemes (ftp)" do
        subject.original_url = "ftp://example.com"
        expect(subject).not_to be_valid
        expect(subject.errors[:original_url]).to include(I18n.t('activerecord.errors.models.short_link.attributes.original_url.invalid_format'))
      end

      it "rejects unparseable garbage" do
        subject.original_url = "http://exa mple.com"
        expect(subject).not_to be_valid
      end
    end
  end

  describe ".shorten" do
    context "Input Normalization" do
      it "strips trailing slashes from the URL" do
        link = described_class.shorten("https://google.com/")
        expect(link.original_url).to eq("https://google.com")
      end

      it "strips whitespace" do
        link = described_class.shorten("  https://google.com  ")
        expect(link.original_url).to eq("https://google.com")
      end
    end

    context "New Record Creation (Happy Path)" do
      let(:mock_id) { 100 }
      let(:mock_slug) { "1C" }

      before do
        allow(IdSequencer).to receive(:next_id).and_return(mock_id)
        allow(SlugGenerator).to receive(:encode).with(mock_id).and_return(mock_slug)
      end

      it "creates a new record with the reserved ID and calculated Slug" do
        expect {
          described_class.shorten(valid_url)
        }.to change(ShortLink, :count).by(1)

        link = ShortLink.last
        expect(link.id).to eq(mock_id)
        expect(link.slug).to eq(mock_slug)
        expect(link.original_url).to eq(valid_url)
      end

      it "calls IdSequencer and SlugGenerator exactly once" do
        expect(IdSequencer).to receive(:next_id).once
        expect(SlugGenerator).to receive(:encode).once
        described_class.shorten(valid_url)
      end
    end

    context "Optimization (Existing Record)" do
      let!(:existing_link) { described_class.create!(original_url: valid_url, id: 999, slug: "abc") }

      it "returns the existing record" do
        result = described_class.shorten(valid_url)
        expect(result.id).to eq(existing_link.id)
      end

      it "does NOT call IdSequencer (saves database calls/burning IDs)" do
        expect(IdSequencer).not_to receive(:next_id)
        described_class.shorten(valid_url)
      end

      it "handles normalized duplicates (e.g. input has slash, DB does not)" do
        url_with_slash = "#{valid_url}/"

        expect {
          result = described_class.shorten(url_with_slash)
          expect(result.id).to eq(existing_link.id)
        }.not_to change(ShortLink, :count)
      end
    end

    context "Race Condition Handling (The 'Block' Logic)" do
      # SCENARIO:
      # 1. The 'find_by' guard clause returns nil (we think it's new).
      # 2. We calculate ID/Slug.
      # 3. Before we save, ANOTHER process inserts the same URL.
      # 4. 'create_or_find_by!' hits a DB Unique Constraint.
      # 5. Rails catches it and finds the record the OTHER process made.

      it "recovers gracefully by finding the record created by another process" do
        # 1. Force the first find_by to miss (simulating race condition window)
        allow(described_class).to receive(:find_by).with(original_url: valid_url).and_return(nil)

        # 2. Create the 'phantom' record that appeared out of nowhere
        phantom_record = described_class.create!(original_url: valid_url, id: 555, slug: "phantom")

        # 3. Ensure IdSequencer is called (because we passed the guard clause)
        allow(IdSequencer).to receive(:next_id).and_return(666) # We try to save as ID 666

        # 4. Now, call shorten.
        # It should return the phantom_record (ID 555), NOT our new ID (666).

        result = described_class.shorten(valid_url)

        expect(result.id).to eq(phantom_record.id)
        expect(result.id).not_to eq(666)
        expect(ShortLink.count).to eq(1)
      end
    end

    context "Validation Failures" do
      let(:error_message) { I18n.t('short_links.errors.url_blank') }

      it "raises an ArgumentError for nil" do
        expect {
          described_class.shorten(nil)
        }.to raise_error(ShortLink::BlankUrlError, error_message)
      end

      it "raises an ArgumentError for whitespace strings" do
        expect {
          described_class.shorten("   ")
        }.to raise_error(ShortLink::BlankUrlError, error_message)
      end

      it "raises an error if the URL is invalid (doesn't silently return nil)" do
        expect {
          described_class.shorten("ftp://invalid-scheme.com")
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
