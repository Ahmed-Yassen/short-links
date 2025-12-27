require 'rails_helper'

RSpec.describe "Links API", type: :request do
  let(:headers) { { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" } }
  let(:valid_url) { "https://google.com" }
  let(:invalid_url) { "ftp://bad-scheme.com" }

  describe "POST /encode" do
    context "Happy Path (Success)" do
      it "returns 201 Created when a NEW link is created" do
        post "/encode", params: { url: valid_url }.to_json, headers: headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["original_url"]).to eq(valid_url)
        expect(json["short_url"]).to match(%r{http://www.example.com/[a-zA-Z0-9]+})
        expect(ShortLink.count).to eq(1)
      end

      it "returns 200 OK when an EXISTING link is requested (Idempotency)" do
        existing_link = create(:short_link, original_url: valid_url)

        post "/encode", params: { url: valid_url }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["short_url"]).to end_with(existing_link.slug)
        expect(ShortLink.count).to eq(1)
      end
    end

    context "Error Path (Validation & input)" do
      it "returns 400 Bad Request when 'url' param is missing" do
        post "/encode", params: {}.to_json, headers: headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json["error"]).to match(/param is missing/)
      end

      it "returns 400 Bad Request when 'url' is blank string" do
        post "/encode", params: { url: "" }.to_json, headers: headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to match(/param is missing/)
      end

      it "returns 422 Unprocessable Entity for invalid URL format" do
        post "/encode", params: { url: invalid_url }.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json["error"]).to include("must be a valid HTTP/HTTPS URL")
      end

      it "returns 422 Unprocessable Entity for recursive links" do
        allow(ENV).to receive(:[]).with("APP_HOST").and_return("myshortner.com")

        recursive_url = "http://myshortner.com/some-slug"

        post "/encode", params: { url: recursive_url }.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("cannot be a link to this service")
      end
    end
  end

  describe "POST /decode" do
    let!(:link) { create(:short_link, original_url: "https://google.com") }

    context "Happy Path (Success)" do
      it "decodes a raw slug" do
        post "/decode", params: { url: link.slug }.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["original_url"]).to eq("https://google.com")
      end

      it "decodes a full URL containing the slug" do
        full_url = "http://short.ly/#{link.slug}"
        post "/decode", params: { url: full_url }.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["original_url"]).to eq("https://google.com")
      end
    end

    context "Error Path" do
      it "returns 404 Not Found if the slug does not exist" do
        post "/decode", params: { url: "missing-slug" }.to_json, headers: headers
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)["error"]).to eq("Short link not found")
      end

      it "returns 400 Bad Request when 'url' param is missing" do
        post "/decode", params: {}.to_json, headers: headers
        expect(response).to have_http_status(:bad_request)
      end

      it "returns 404 Not Found for a malformed slug that looks like a URL" do
        post "/decode", params: { url: "http://short.ly/garbage" }.to_json, headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
