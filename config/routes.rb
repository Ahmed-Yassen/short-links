Rails.application.routes.draw do
  post "/encode", to: "links#encode"
  post "/decode", to: "links#decode"
end
