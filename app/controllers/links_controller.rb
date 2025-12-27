class LinksController < ApplicationController
  def encode
    url = encode_params
    link = ShortLink.shorten(url)
    LinkRepository.warm_cache(link)
    status = link.previously_new_record? ? :created : :ok

    render json: {
      short_url: construct_short_url(link.slug),
      original_url: link.original_url
    }, status: status
  end

  def decode
    url = decode_params
    slug = extract_slug(url)

    original_url = LinkRepository.find_original_url(slug)

    render json: { original_url: original_url }, status: :ok
  end

  private

  def encode_params
    params.require(:url)
  end

  def decode_params
    params.require(:url)
  end

  def construct_short_url(slug)
    "#{request.base_url}/#{slug}"
  end

  def extract_slug(url_or_slug)
    return nil if url_or_slug.blank?
    url_or_slug.to_s.split("/").last
  end
end
