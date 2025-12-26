FactoryBot.define do
  factory :short_link do
    sequence(:original_url) { |n| "https://example.com/page/#{n}" }
    sequence(:slug) { |n| SlugGenerator.encode(n) }
  end
end
