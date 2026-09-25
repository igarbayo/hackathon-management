require "rails_helper"

# RF-API-012, RNF-SEC-015, RNF-API-004: full authorization_code + PKCE flow, and
# the explicit cases RNF-API-004 asks for (wrong PKCE, different redirect_uri,
# another resource, reused code, reused refresh token).
RSpec.describe "Full OAuth 2.1 flow", type: :request do
  def pkce_pair
    verifier = SecureRandom.urlsafe_base64(32)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    [ verifier, challenge ]
  end

  let(:membership) { create(:membership) }
  let(:client) { create(:oauth_client, redirect_uris: [ "https://claude.ai/callback" ]) }
  let(:resource) { "http://api.test/api/v1/mcp" }

  around do |example|
    original = ENV["API_URL"]
    ENV["API_URL"] = "http://api.test"
    example.run
    ENV["API_URL"] = original
  end

  def authorize_params(verifier_pair)
    {
      response_type: "code", client_id: client.client_id, redirect_uri: client.redirect_uris.first,
      scope: "read features:write", state: "xyz123", code_challenge: verifier_pair[1],
      code_challenge_method: "S256", resource: resource
    }
  end

  def request_id_from_redirect
    location = URI.parse(response.headers["Location"])
    URI.decode_www_form(location.query.to_s).to_h["request_id"]
  end

  def query_param(url, name)
    URI.decode_www_form(URI.parse(url).query.to_s).to_h[name]
  end

  def decide(request_id, approve:, team_id: nil, scopes: nil)
    body = { request_id: request_id, approve: approve }
    body[:team_id] = team_id if team_id
    body[:scopes] = scopes if scopes

    post "/oauth/authorize/decision", params: body, headers: csrf_headers, as: :json
  end

  it "GET /oauth/authorize with no session first sends to /login with next pointing to the consent" do
    get "/oauth/authorize", params: authorize_params(pkce_pair)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/login?next=")
  end

  it "GET /oauth/authorize with a session goes straight to the consent" do
    sign_in_as(membership.user)

    get "/oauth/authorize", params: authorize_params(pkce_pair)

    expect(response.headers["Location"]).to include("/oauth/consent?request_id=")
  end

  it "unknown client_id: direct error, never redirects (it is not a trusted redirect_uri)" do
    get "/oauth/authorize", params: authorize_params(pkce_pair).merge(client_id: "does-not-exist")

    expect(response).to have_http_status(:bad_request)
  end

  it "unregistered redirect_uri: direct error" do
    get "/oauth/authorize", params: authorize_params(pkce_pair).merge(redirect_uri: "https://other.example.com/cb")

    expect(response).to have_http_status(:bad_request)
  end

  it "another resource: redirects with error=invalid_target, with redirect_uri already validated" do
    get "/oauth/authorize", params: authorize_params(pkce_pair).merge(resource: "https://malicioso.example.com")

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to start_with("https://claude.ai/callback")
    expect(response.headers["Location"]).to include("error=invalid_target")
  end

  it "GET /oauth/consent_info returns the client name and the requested scopes" do
    sign_in_as(membership.user)
    get "/oauth/authorize", params: authorize_params(pkce_pair)
    request_id = request_id_from_redirect

    get "/oauth/consent_info", params: { request_id: request_id }

    expect(json_response["client"]["name"]).to eq(client.name)
    expect(json_response["scopes"]).to eq(%w[read features:write])
    expect(json_response["redirect_uri"]).to eq(client.redirect_uris.first)
  end

  describe "end to end" do
    it "approving the consent and exchanging the code gives a valid token for that resource" do
      verifier, challenge = pkce_pair
      sign_in_as(membership.user)
      get "/oauth/authorize", params: authorize_params([ verifier, challenge ])
      request_id = request_id_from_redirect

      decide(request_id, approve: true, team_id: membership.team.id.to_s, scopes: [ "read" ])

      expect(response).to have_http_status(:ok)
      code = query_param(json_response["redirect_url"], "code")
      state = query_param(json_response["redirect_url"], "state")
      expect(state).to eq("xyz123")
      expect(json_response["redirect_url"]).to start_with("https://claude.ai/callback")

      post "/oauth/token", params: {
        grant_type: "authorization_code", code: code, redirect_uri: client.redirect_uris.first,
        client_id: client.client_id, code_verifier: verifier
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["access_token"]).to start_with("hb_oat_")
      expect(json_response["refresh_token"]).to start_with("hb_ort_")

      resolved = Tokens::Resolve.call(json_response["access_token"], expected_resource: resource)
      expect(resolved).to be_present
      expect(resolved.team).to eq(membership.team)
    end

    it "denying the consent gives a redirect_url with error=access_denied" do
      verifier, challenge = pkce_pair
      sign_in_as(membership.user)
      get "/oauth/authorize", params: authorize_params([ verifier, challenge ])
      request_id = request_id_from_redirect

      decide(request_id, approve: false)

      expect(json_response["redirect_url"]).to include("error=access_denied")
    end

    it "cannot ask for more scope than was authorized in /authorize" do
      verifier, challenge = pkce_pair
      sign_in_as(membership.user)
      get "/oauth/authorize", params: authorize_params([ verifier, challenge ]).merge(scope: "read")
      request_id = request_id_from_redirect

      decide(request_id, approve: true, team_id: membership.team.id.to_s, scopes: [ "read", "features:write", "milestones:write" ])

      expect(json_response["redirect_url"]).to include("error=invalid_scope")
    end

    it "requires a session and CSRF to decide" do
      sign_in_as(membership.user)
      get "/oauth/authorize", params: authorize_params(pkce_pair)
      request_id = request_id_from_redirect

      post "/oauth/authorize/decision", params: { request_id: request_id, approve: true, team_id: membership.team.id.to_s }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "RNF-API-004: explicit cases" do
    def issue_code(verifier_pair)
      sign_in_as(membership.user)
      get "/oauth/authorize", params: authorize_params(verifier_pair)
      request_id = request_id_from_redirect

      decide(request_id, approve: true, team_id: membership.team.id.to_s, scopes: [ "read" ])

      query_param(json_response["redirect_url"], "code")
    end

    it "wrong PKCE: a code_verifier that does not match the challenge" do
      verifier, challenge = pkce_pair
      code = issue_code([ verifier, challenge ])

      post "/oauth/token", params: {
        grant_type: "authorization_code", code: code, redirect_uri: client.redirect_uris.first,
        client_id: client.client_id, code_verifier: "another-verifier-that-does-not-match"
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json_response["error"]).to eq("invalid_grant")
    end

    it "redirect_uri different from the one in /authorize" do
      verifier, challenge = pkce_pair
      client.update!(redirect_uris: client.redirect_uris + [ "https://claude.ai/other" ])
      code = issue_code([ verifier, challenge ])

      post "/oauth/token", params: {
        grant_type: "authorization_code", code: code, redirect_uri: "https://claude.ai/other",
        client_id: client.client_id, code_verifier: verifier
      }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "reused code" do
      verifier, challenge = pkce_pair
      code = issue_code([ verifier, challenge ])
      body = { grant_type: "authorization_code", code: code, redirect_uri: client.redirect_uris.first, client_id: client.client_id, code_verifier: verifier }

      post "/oauth/token", params: body, as: :json
      expect(response).to have_http_status(:ok)

      post "/oauth/token", params: body, as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "another resource: a token for /api/v1/mcp does not work on the REST API" do
      verifier, challenge = pkce_pair
      code = issue_code([ verifier, challenge ])
      post "/oauth/token", params: {
        grant_type: "authorization_code", code: code, redirect_uri: client.redirect_uris.first,
        client_id: client.client_id, code_verifier: verifier
      }, as: :json
      access_token = json_response["access_token"]

      resolved_for_rest = Tokens::Resolve.call(access_token, expected_resource: "http://api.test/api/v1")
      expect(resolved_for_rest).to be_nil

      resolved_for_mcp = Tokens::Resolve.call(access_token, expected_resource: resource)
      expect(resolved_for_mcp).to be_present
    end

    it "reused refresh token: revokes the whole connection, including the new one" do
      verifier, challenge = pkce_pair
      code = issue_code([ verifier, challenge ])
      post "/oauth/token", params: {
        grant_type: "authorization_code", code: code, redirect_uri: client.redirect_uris.first,
        client_id: client.client_id, code_verifier: verifier
      }, as: :json
      first_refresh = json_response["refresh_token"]

      post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: first_refresh, client_id: client.client_id }, as: :json
      expect(response).to have_http_status(:ok)
      second_access = json_response["access_token"]

      # Reusing the already rotated refresh token: the theft is detected.
      post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: first_refresh, client_id: client.client_id }, as: :json
      expect(response).to have_http_status(:bad_request)

      # And it also revokes the token that came out of the legitimate rotation.
      expect(Tokens::Resolve.call(second_access, expected_resource: resource)).to be_nil
    end
  end

  it "POST /oauth/revoke invalidates the token" do
    verifier, challenge = pkce_pair
    sign_in_as(membership.user)
    get "/oauth/authorize", params: {
      response_type: "code", client_id: client.client_id, redirect_uri: client.redirect_uris.first,
      scope: "read", state: "s", code_challenge: challenge, code_challenge_method: "S256", resource: resource
    }
    request_id = request_id_from_redirect
    decide(request_id, approve: true, team_id: membership.team.id.to_s, scopes: [ "read" ])
    code = query_param(json_response["redirect_url"], "code")

    post "/oauth/token", params: {
      grant_type: "authorization_code", code: code, redirect_uri: client.redirect_uris.first,
      client_id: client.client_id, code_verifier: verifier
    }, as: :json
    access_token = json_response["access_token"]

    post "/oauth/revoke", params: { token: access_token }, as: :json
    expect(response).to have_http_status(:ok)
    expect(Tokens::Resolve.call(access_token, expected_resource: resource)).to be_nil
  end
end
