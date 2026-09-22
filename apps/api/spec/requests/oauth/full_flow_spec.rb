require "rails_helper"

# RF-API-012, RNF-SEC-015, RNF-API-004: flujo completo authorization_code +
# PKCE, y los casos explícitos que pide RNF-API-004 (PKCE incorrecto,
# redirect_uri distinto, resource ajeno, código reutilizado, refresh
# reutilizado).
RSpec.describe "Flujo OAuth 2.1 completo", type: :request do
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

  it "GET /oauth/authorize sin sesión manda antes a /login con next hacia el consentimiento" do
    get "/oauth/authorize", params: authorize_params(pkce_pair)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/login?next=")
  end

  it "GET /oauth/authorize con sesión manda directo al consentimiento" do
    sign_in_as(membership.user)

    get "/oauth/authorize", params: authorize_params(pkce_pair)

    expect(response.headers["Location"]).to include("/oauth/consent?request_id=")
  end

  it "client_id desconocido: error directo, nunca redirige (no es un redirect_uri de confianza)" do
    get "/oauth/authorize", params: authorize_params(pkce_pair).merge(client_id: "no-existe")

    expect(response).to have_http_status(:bad_request)
  end

  it "redirect_uri no registrado: error directo" do
    get "/oauth/authorize", params: authorize_params(pkce_pair).merge(redirect_uri: "https://otro.example.com/cb")

    expect(response).to have_http_status(:bad_request)
  end

  it "resource ajeno: redirige con error=invalid_target, ya con redirect_uri validado" do
    get "/oauth/authorize", params: authorize_params(pkce_pair).merge(resource: "https://malicioso.example.com")

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to start_with("https://claude.ai/callback")
    expect(response.headers["Location"]).to include("error=invalid_target")
  end

  it "GET /oauth/consent_info devuelve el nombre del cliente y los scopes pedidos" do
    sign_in_as(membership.user)
    get "/oauth/authorize", params: authorize_params(pkce_pair)
    request_id = request_id_from_redirect

    get "/oauth/consent_info", params: { request_id: request_id }

    expect(json_response["client"]["name"]).to eq(client.name)
    expect(json_response["scopes"]).to eq(%w[read features:write])
  end

  describe "de principio a fin" do
    it "aprobar el consentimiento y canjear el código da un token válido para ese resource" do
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

    it "rechazar el consentimiento da un redirect_url con error=access_denied" do
      verifier, challenge = pkce_pair
      sign_in_as(membership.user)
      get "/oauth/authorize", params: authorize_params([ verifier, challenge ])
      request_id = request_id_from_redirect

      decide(request_id, approve: false)

      expect(json_response["redirect_url"]).to include("error=access_denied")
    end

    it "no se puede pedir más scope del que se autorizó en /authorize" do
      verifier, challenge = pkce_pair
      sign_in_as(membership.user)
      get "/oauth/authorize", params: authorize_params([ verifier, challenge ]).merge(scope: "read")
      request_id = request_id_from_redirect

      decide(request_id, approve: true, team_id: membership.team.id.to_s, scopes: [ "read", "features:write", "milestones:write" ])

      expect(json_response["redirect_url"]).to include("error=invalid_scope")
    end

    it "exige sesión y CSRF para decidir" do
      sign_in_as(membership.user)
      get "/oauth/authorize", params: authorize_params(pkce_pair)
      request_id = request_id_from_redirect

      post "/oauth/authorize/decision", params: { request_id: request_id, approve: true, team_id: membership.team.id.to_s }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "RNF-API-004: casos explícitos" do
    def issue_code(verifier_pair)
      sign_in_as(membership.user)
      get "/oauth/authorize", params: authorize_params(verifier_pair)
      request_id = request_id_from_redirect

      decide(request_id, approve: true, team_id: membership.team.id.to_s, scopes: [ "read" ])

      query_param(json_response["redirect_url"], "code")
    end

    it "PKCE incorrecto: code_verifier que no coincide con el challenge" do
      verifier, challenge = pkce_pair
      code = issue_code([ verifier, challenge ])

      post "/oauth/token", params: {
        grant_type: "authorization_code", code: code, redirect_uri: client.redirect_uris.first,
        client_id: client.client_id, code_verifier: "otro-verifier-que-no-es"
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json_response["error"]).to eq("invalid_grant")
    end

    it "redirect_uri distinto al de /authorize" do
      verifier, challenge = pkce_pair
      client.update!(redirect_uris: client.redirect_uris + [ "https://claude.ai/otro" ])
      code = issue_code([ verifier, challenge ])

      post "/oauth/token", params: {
        grant_type: "authorization_code", code: code, redirect_uri: "https://claude.ai/otro",
        client_id: client.client_id, code_verifier: verifier
      }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "código reutilizado" do
      verifier, challenge = pkce_pair
      code = issue_code([ verifier, challenge ])
      body = { grant_type: "authorization_code", code: code, redirect_uri: client.redirect_uris.first, client_id: client.client_id, code_verifier: verifier }

      post "/oauth/token", params: body, as: :json
      expect(response).to have_http_status(:ok)

      post "/oauth/token", params: body, as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "resource ajeno: un token para /api/v1/mcp no vale para la API REST" do
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

    it "refresh token reutilizado: revoca toda la conexión, incluido el nuevo" do
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

      # Reusar el refresh token ya rotado: se detecta el robo.
      post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: first_refresh, client_id: client.client_id }, as: :json
      expect(response).to have_http_status(:bad_request)

      # Y revoca también el token que había salido de la rotación legítima.
      expect(Tokens::Resolve.call(second_access, expected_resource: resource)).to be_nil
    end
  end

  it "POST /oauth/revoke invalida el token" do
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
