require "rails_helper"

RSpec.describe "GET /up", type: :request do
  it "responde 200 cuando la app arranca sin excepciones" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
