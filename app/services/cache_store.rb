class CacheStore
  TTL = 24.hours.to_i

  def self.read(key)
    $redis.get(key)
  end

  def self.write(key, value)
    $redis.setex(key, TTL, value)
  end
end
