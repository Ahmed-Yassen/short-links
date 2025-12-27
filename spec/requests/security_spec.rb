require 'rails_helper'

RSpec.describe "Security Strategy", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:headers) { { "CONTENT_TYPE" => "application/json" } }
  let (:url) { "https://example.com" }

  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear!
  end

  after do
    Rack::Attack.enabled = false
  end

  describe "Rate Limiting" do
    it "throttles excessive requests to /encode" do
      limit = 10

      (limit).times do
        post "/encode", params: { url: url }.to_json, headers: headers
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post "/encode", params: { url: url }.to_json, headers: headers

      expect(response).to have_http_status(:too_many_requests)
      expect(JSON.parse(response.body)["error"]).to include("Rate limit exceeded")
    end

    it "resets the limit after the period expires" do
      limit = 10

      limit.times do
        post "/encode", params: { url: url }.to_json, headers: headers
      end

      post "/encode", params: { url: url }.to_json, headers: headers
      expect(response).to have_http_status(:too_many_requests)

      travel(2.minutes) do
        post "/encode", params: { url: url }.to_json, headers: headers
        expect(response).to have_http_status(:created).or have_http_status(:ok)
      end
    end
  end
end
