require "rails_helper"

RSpec.describe "Auth", type: :request do
  describe "POST /api/v1/auth/signup" do
    it "crea el usuario y abre sesión" do
      post "/api/v1/auth/signup",
           params: { email: "ada@example.com", name: "Ada", password: "supersecret123" },
           headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["email"]).to eq("ada@example.com")
      expect(response.cookies["hb_session"]).to be_present
    end

    it "rechaza contraseñas de menos de 10 caracteres" do
      post "/api/v1/auth/signup",
           params: { email: "ada@example.com", name: "Ada", password: "corta" },
           headers: csrf_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["error"]["code"]).to eq("validation_failed")
    end

    it "aplica rate limit tras 10 registros por IP (RNF-SEC-005)" do
      headers = csrf_headers

      10.times do |i|
        post "/api/v1/auth/signup", params: { email: "user#{i}@example.com", name: "U#{i}", password: "supersecret123" }, headers: headers, as: :json
      end

      post "/api/v1/auth/signup", params: { email: "one-more@example.com", name: "Uno más", password: "supersecret123" }, headers: headers, as: :json

      expect(response).to have_http_status(:too_many_requests)
    end

    it "exige X-CSRF-Token" do
      post "/api/v1/auth/signup", params: { email: "ada@example.com", name: "Ada", password: "supersecret123" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json_response["error"]["code"]).to eq("forbidden")
    end
  end

  describe "POST /api/v1/auth/login" do
    it "abre sesión con credenciales correctas" do
      create(:user, email: "ada@example.com", password: "supersecret123")

      post "/api/v1/auth/login", params: { email: "ada@example.com", password: "supersecret123" },
                                  headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.cookies["hb_session"]).to be_present
    end

    it "responde 401 con credenciales incorrectas, sin revelar cuál falló" do
      create(:user, email: "ada@example.com", password: "supersecret123")

      post "/api/v1/auth/login", params: { email: "ada@example.com", password: "mala" },
                                  headers: csrf_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "aplica rate limit tras 10 intentos por email" do
      create(:user, email: "ada@example.com", password: "supersecret123")
      headers = csrf_headers

      10.times do
        post "/api/v1/auth/login", params: { email: "ada@example.com", password: "mala" }, headers: headers, as: :json
      end

      post "/api/v1/auth/login", params: { email: "ada@example.com", password: "mala" }, headers: headers, as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
    end
  end

  describe "GET /api/v1/me" do
    it "requiere autenticación" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "devuelve el usuario y sus membresías" do
      user = create(:user)
      team = create(:team)
      create(:membership, user: user, team: team, role: "owner")
      sign_in_as(user)

      get "/api/v1/me"

      expect(response).to have_http_status(:ok)
      expect(json_response["memberships"].first["team_id"]).to eq(team.id.to_s)
    end
  end

  describe "DELETE /api/v1/me" do
    it "borra la cuenta si no bloquea ningún equipo" do
      user = create(:user)
      sign_in_as(user)

      delete "/api/v1/me", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(User.where(id: user.id).first).to be_nil
    end

    it "borra lógicamente el equipo si era el único miembro" do
      membership = create(:membership, :owner)
      team = membership.team
      sign_in_as(membership.user)

      delete "/api/v1/me", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(team.reload.deleted_at).to be_present
    end

    it "falla si es el único owner de un equipo con más miembros" do
      owner = create(:membership, :owner)
      create(:membership, team: owner.team)
      sign_in_as(owner.user)

      delete "/api/v1/me", headers: csrf_headers

      expect(response).to have_http_status(:conflict)
      expect(User.where(id: owner.user.id).first).to be_present
    end

    it "no falla si hay otro owner" do
      owner_a = create(:membership, :owner)
      create(:membership, :owner, team: owner_a.team)
      sign_in_as(owner_a.user)

      delete "/api/v1/me", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /api/v1/auth/logout" do
    it "invalida la sesión" do
      user = create(:user)
      sign_in_as(user)

      post "/api/v1/auth/logout", headers: csrf_headers

      expect(response).to have_http_status(:no_content)

      get "/api/v1/me"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GitHub login (RF-AUTH-004)" do
    it "redirige a GitHub con un state firmado" do
      get "/api/v1/auth/github"

      expect(response).to have_http_status(:found)
      expect(response.location).to start_with("https://github.com/login/oauth/authorize")
    end

    it "crea el usuario y abre sesión en el callback" do
      stub_request(:post, "https://github.com/login/oauth/access_token")
        .to_return(status: 200, body: { access_token: "gh_token_123" }.to_json, headers: { "Content-Type" => "application/json" })

      stub_request(:get, "https://api.github.com/user")
        .to_return(status: 200, body: {
          id: 4242, login: "ada", name: "Ada Lovelace", email: "ada@github.example.com", avatar_url: "https://avatars/ada.png"
        }.to_json, headers: { "Content-Type" => "application/json" })

      get "/api/v1/auth/github"
      state = Rack::Utils.parse_query(URI.parse(response.location).query)["state"]

      get "/api/v1/auth/github/callback", params: { code: "abc123", state: state }

      expect(response).to have_http_status(:found)
      expect(response.cookies["hb_session"]).to be_present
      expect(User.where(github_uid: 4242).first).to be_present
    end

    it "rechaza un state inválido" do
      get "/api/v1/auth/github/callback", params: { code: "abc123", state: "not-a-real-state" }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "Google login (RF-AUTH-008)" do
    it "valida el id_token (firma, iss, aud, nonce, email_verified)" do
      rsa_key = OpenSSL::PKey::RSA.generate(2048)
      jwk = JWT::JWK.new(rsa_key, { kid: "test-kid" })

      stub_request(:get, "https://www.googleapis.com/oauth2/v3/certs")
        .to_return(status: 200, body: { keys: [ jwk.export ] }.to_json, headers: { "Content-Type" => "application/json" })

      get "/api/v1/auth/google"
      state = Rack::Utils.parse_query(URI.parse(response.location).query)["state"]
      nonce = Rack::Utils.parse_query(URI.parse(response.location).query)["nonce"]

      id_token = JWT.encode(
        {
          iss: "https://accounts.google.com",
          aud: ENV.fetch("GOOGLE_CLIENT_ID", ""),
          sub: "google-sub-1",
          email: "ada@gmail.example.com",
          email_verified: true,
          nonce: nonce,
          name: "Ada Lovelace",
          exp: 10.minutes.from_now.to_i
        },
        rsa_key, "RS256", { kid: "test-kid" }
      )

      stub_request(:post, "https://oauth2.googleapis.com/token")
        .to_return(status: 200, body: { id_token: id_token }.to_json, headers: { "Content-Type" => "application/json" })

      get "/api/v1/auth/google/callback", params: { code: "abc123", state: state }

      expect(response).to have_http_status(:found)
      expect(User.where(google_sub: "google-sub-1").first).to be_present
    end
  end
end
