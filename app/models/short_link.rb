class ShortLink < ApplicationRecord
  validates :original_url, presence: true, url: { no_recursion: true }

  class BlankUrlError < StandardError; end

  def self.shorten(url)
    raise BlankUrlError, I18n.t("short_links.errors.url_blank") if url.blank?

    clean_url = url.strip.chomp("/")

    if existing = find_by(original_url: clean_url)
      return existing
    end

    next_id = IdSequencer.next_id(table_name)
    new_slug = SlugGenerator.encode(next_id)

    # Handle Race-condition, use the block to set ID/Slug so they don't pollute the 'Find' query if a conflict occurs.
    create_or_find_by!(original_url: clean_url) do |link|
      link.id = next_id
      link.slug = new_slug
    end
  end
end
