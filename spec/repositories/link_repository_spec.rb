require 'rails_helper'

RSpec.describe LinkRepository do
  let(:slug) { "abc" }
  let(:url) { "https://google.com" }
  let(:cache_key) { "short_link:#{slug}" }

  describe ".find_original_url" do
    context "when data is in Cache" do
      it "returns data from CacheStore without hitting DB" do
        allow(CacheStore).to receive(:read).with(cache_key).and_return(url)

        expect(ShortLink).not_to receive(:find_by!)

        result = described_class.find_original_url(slug)
        expect(result).to eq(url)
      end
    end

    context "when data is missing from Cache" do
      before do
        allow(CacheStore).to receive(:read).and_return(nil)
        allow(CacheStore).to receive(:write)
      end

      it "fetches from DB and writes to CacheStore" do
        create(:short_link, slug: slug, original_url: url)

        expect(CacheStore).to receive(:write).with(cache_key, url)

        result = described_class.find_original_url(slug)
        expect(result).to eq(url)
      end

      it "raises RecordNotFound if missing from both" do
        expect {
          described_class.find_original_url("missing")
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
