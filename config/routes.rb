Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  post "/encode", to: "links#encode"
  post "/decode", to: "links#decode"
end
