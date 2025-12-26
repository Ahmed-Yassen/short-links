class UrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    begin
      uri = URI.parse(value)

      unless uri.is_a?(URI::HTTP) && uri.host.present?
        record.errors.add(attribute, :invalid_format)
        return
      end

      record.errors.add(attribute, :recursive_link) if options[:no_recursion] && recursive_link?(uri)

    rescue URI::InvalidURIError
      record.errors.add(attribute, :invalid_format)
    end
  end

  private

  def recursive_link?(uri)
    app_host = extract_host(app_base_url)

    forbidden_hosts = [ app_host, "localhost", "127.0.0.1" ].compact.map(&:downcase)

    forbidden_hosts.include?(uri.host.downcase)
  end

  def app_base_url
    ENV["APP_HOST"] || Rails.application.routes.default_url_options[:host]
  end

  def extract_host(url)
    return nil if url.blank?

    url = "http://#{url}" unless url.include?("://")
    URI.parse(url).host
  rescue URI::InvalidURIError
    nil
  end
end
