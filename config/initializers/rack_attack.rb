class Rack::Attack
  class RedisCacheAdapter
    def initialize(client)
      @redis = client
    end

    def read(key)
      @redis.get(key)
    end

    def write(key, value, options = {})
      if options[:expires_in]
        @redis.setex(key, options[:expires_in].to_i, value)
      else
        @redis.set(key, value)
      end
    end

    def increment(key, amount, options = {})
      count = @redis.incrby(key, amount)

      @redis.expire(key, options[:expires_in].to_i) if count == amount && options[:expires_in]

      count
    end

    def delete_matched(matcher)
      redis_pattern = matcher.is_a?(Regexp) ? "*" : matcher

      cursor = "0"
      loop do
        cursor, keys = @redis.scan(cursor, match: redis_pattern, count: 100)

        if matcher.is_a?(Regexp)
          keys.select! { |key| key.match?(matcher) }
        end

        @redis.del(*keys) if keys.any?

        break if cursor == "0"
      end
    end

    def clear!
      @redis.flushdb
    end
  end

  redis_client = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  Rack::Attack.cache.store = RedisCacheAdapter.new(redis_client)

  safelist("allow-localhost") do |req|
    next false if Rails.env.test?

    "127.0.0.1" == req.ip || "::1" == req.ip
  end

  throttle("req/ip", limit: 60, period: 1.minute) do |req|
    req.ip
  end

  throttle("links/encode", limit: 10, period: 1.minute) do |req|
    if req.path == "/encode" && req.post?
      req.ip
    end
  end

  self.throttled_responder = lambda do |env|
    [ 429,
      { "Content-Type" => "application/json" },
      [ { error: I18n.t("api.errors.rate_limit_exceeded") }.to_json ]
    ]
  end
end

Rack::Attack.enabled = !Rails.env.test?
