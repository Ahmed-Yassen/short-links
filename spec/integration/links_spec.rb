require 'swagger_helper'

RSpec.describe 'Short Link API', type: :request do
  path '/encode' do
    post 'Creates a short link' do
      tags 'Links'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :link, in: :body, schema: {
        type: :object,
        properties: {
          url: { type: :string, example: 'https://www.google.com' }
        },
        required: [ 'url' ]
      }

      response '200', 'link found (idempotent)' do
        let(:link) { { url: 'https://www.google.com' } }

        before do
          ShortLink.create!(original_url: 'https://www.google.com', slug: 'existing')
        end

        run_test!
      end

      response '201', 'link created' do
        let(:link) { { url: "https://www.example.com/#{SecureRandom.hex}" } }
        run_test!
      end

      response '400', 'invalid request' do
        let(:link) { { url: '' } }
        run_test!
      end
    end
  end

  path '/decode' do
    post 'Decodes a short link' do
      tags 'Links'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          url: { type: :string, example: 'http://myshortner.com/X' }
        },
        required: [ 'url' ]
      }

      response '200', 'link decoded' do
        let(:short_link) { ShortLink.create!(original_url: 'https://google.com', slug: 'abc') }
        let(:body) { { url: short_link.slug } }
        run_test!
      end

      response '404', 'link not found' do
        let(:body) { { url: 'NONEXISTENT' } }
        run_test!
      end
    end
  end
end
