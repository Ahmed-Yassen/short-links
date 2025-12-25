class SlugGenerator
  # We fetch from ENV to keep the shuffle secret in production.
  # We provide a default fallback so the app works immediately in Dev/Test without setup.
  ALPHABET = ENV.fetch(
    "BASE62_ALPHABET",
    "5hK8XzN9pQ2w4rRstuT7vWxmYyZ136AbBcCdDeEfFgGHiJkLnMjPqS"
  ).chars
  BASE = ALPHABET.length

  def self.encode(input)
    begin
      id = Integer(input)
    rescue ArgumentError, TypeError
      raise ArgumentError, I18n.t("slug_generator.errors.invalid_input")
    end

    if id < 0
      raise ArgumentError, I18n.t("slug_generator.errors.invalid_input")
    end

    return ALPHABET[0] if id == 0

    s = ""
    while id > 0
      s << ALPHABET[id % BASE]
      id /= BASE
    end

    s.reverse
  end

  def self.decode(slug)
    return nil if slug.blank?

    slug.chars.reduce(0) do |id, char|
      return nil unless ALPHABET.include?(char)
      id * BASE + ALPHABET.index(char)
    end
  end
end
