require "rails_helper"

RSpec.describe "OAuth 2.1 metadata", type: :request do
  around do |example|
    original = ENV["API_URL"]
    ENV["API_URL"] = "https://api.hackboard.test"
    example.run
    ENV["API_URL"] = original
  end

  it "GET /.well-known/oauth-authorization-server (RFC 8414)" do
    get "/.well-known/oauth-authorization-server"

    expect(response).to have_http_status(:ok)
    expect(json_response["issuer"]).to eq("https://api.hackboard.test")
    expect(json_response["authorization_endpoint"]).to eq("https://api.hackboard.test/oauth/authorize")
    expect(json_response["code_challenge_methods_supported"]).to eq([ "S256" ])
  end

  it "GET /.well-known/oauth-protected-resource/api/v1/mcp (RFC 9728)" do
    get "/.well-known/oauth-protected-resource/api/v1/mcp"

    expect(json_response["resource"]).to eq("https://api.hackboard.test/api/v1/mcp")
    expect(json_response["authorization_servers"]).to eq([ "https://api.hackboard.test" ])
  end

  it "GET /.well-known/oauth-protected-resource/api/v1" do
    get "/.well-known/oauth-protected-resource/api/v1"

    expect(json_response["resource"]).to eq("https://api.hackboard.test/api/v1")
  end
end
