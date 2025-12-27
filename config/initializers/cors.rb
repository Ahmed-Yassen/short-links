Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "/decode", headers: :any, methods: [ :post ]
  end

  # allow do
  #   origins ENV.fetch("FE_DOMAIN"), "http://localhost:3000"

  #   resource "/encode",
  #     headers: :any,
  #     methods: [ :post ]
  # end
end
