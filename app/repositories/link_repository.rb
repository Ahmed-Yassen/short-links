class LinkRepository
  CACHE_PREFIX = "short_link"

  def self.find_original_url(slug)
    cache_key = "#{CACHE_PREFIX}:#{slug}"

    if cached_url = CacheStore.read(cache_key)
      return cached_url
    end

    link = ShortLink.find_by!(slug: slug)
    CacheStore.write(cache_key, link.original_url)
    link.original_url
  end

  def self.warm_cache(link)
    cache_key = "#{CACHE_PREFIX}:#{link.slug}"
    CacheStore.write(cache_key, link.original_url)
  end
end
