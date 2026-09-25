require "rails_helper"

RSpec.describe "POST /oauth/register (RFC 7591)", type: :request do
  it "registers a dynamic client with no secret" do
    post "/oauth/register", params: { redirect_uris: [ "https://claude.ai/oauth/callback" ], client_name: "claude.ai" }, as: :json

    expect(response).to have_http_status(:created)
    expect(json_response["client_id"]).to be_present
    expect(json_response["token_endpoint_auth_method"]).to eq("none")
    expect(json_response).not_to have_key("client_secret")
  end

  it "rejects a redirect_uri that is neither https nor loopback" do
    post "/oauth/register", params: { redirect_uris: [ "http://evil.example.com/cb" ], client_name: "bad" }, as: :json

    expect(response).to have_http_status(:bad_request)
  end

  it "accepts http://127.0.0.1 with any port for native apps" do
    post "/oauth/register", params: { redirect_uris: [ "http://127.0.0.1:51823/cb" ], client_name: "native app" }, as: :json

    expect(response).to have_http_status(:created)
  end

  it "applies the rate limit of 10 registrations per hour per IP" do
    10.times { |i| post "/oauth/register", params: { redirect_uris: [ "https://a.example.com/cb" ], client_name: "c#{i}" }, as: :json }

    post "/oauth/register", params: { redirect_uris: [ "https://a.example.com/cb" ], client_name: "c11" }, as: :json

    expect(response).to have_http_status(:too_many_requests)
  end
end
