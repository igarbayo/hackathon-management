require "rails_helper"

RSpec.describe "Auth", type: :request do
  describe "POST /api/v1/auth/signup" do
    it "creates the user and opens a session" do
      post "/api/v1/auth/signup",
           params: { email: "ada@example.com", name: "Ada", password: "supersecret123" },
           headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["email"]).to eq("ada@example.com")
      expect(response.cookies["hb_session"]).to be_present
    end

    it "rejects passwords shorter than 10 characters" do
      post "/api/v1/auth/signup",
           params: { email: "ada@example.com", name: "Ada", password: "short" },
           headers: csrf_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["error"]["code"]).to eq("validation_failed")
    end

    it "rejects passwords longer than 72 bytes" do
      post "/api/v1/auth/signup",
           params: { email: "ada@example.com", name: "Ada", password: "a" * 73 },
           headers: csrf_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["error"]["code"]).to eq("validation_failed")
    end

    it "applies a rate limit after 10 signups per IP (RNF-SEC-005)" do
      headers = csrf_headers

      10.times do |i|
        post "/api/v1/auth/signup", params: { email: "user#{i}@example.com", name: "U#{i}", password: "supersecret123" }, headers: headers, as: :json
      end

      post "/api/v1/auth/signup", params: { email: "one-more@example.com", name: "One more", password: "supersecret123" }, headers: headers, as: :json

      expect(response).to have_http_status(:too_many_requests)
    end

    it "requires X-CSRF-Token" do
      post "/api/v1/auth/signup", params: { email: "ada@example.com", name: "Ada", password: "supersecret123" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json_response["error"]["code"]).to eq("forbidden")
    end
  end

  describe "POST /api/v1/auth/login" do
    it "opens a session with the right credentials" do
      create(:user, email: "ada@example.com", password: "supersecret123")

      post "/api/v1/auth/login", params: { email: "ada@example.com", password: "supersecret123" },
                                  headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.cookies["hb_session"]).to be_present
    end

    it "returns 401 with wrong credentials, without saying which one failed" do
      create(:user, email: "ada@example.com", password: "supersecret123")

      post "/api/v1/auth/login", params: { email: "ada@example.com", password: "wrong" },
                                  headers: csrf_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "applies a rate limit after 10 attempts per email" do
      create(:user, email: "ada@example.com", password: "supersecret123")
      headers = csrf_headers

      10.times do
        post "/api/v1/auth/login", params: { email: "ada@example.com", password: "wrong" }, headers: headers, as: :json
      end

      post "/api/v1/auth/login", params: { email: "ada@example.com", password: "wrong" }, headers: headers, as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
    end
  end

  describe "GET /api/v1/me" do
    it "requires authentication" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the user and their memberships" do
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
    it "deletes the account if it does not block any team" do
      user = create(:user)
      sign_in_as(user)

      delete "/api/v1/me", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(User.where(id: user.id).first).to be_nil
    end

    it "soft-deletes the team if they were its only member" do
      membership = create(:membership, :owner)
      team = membership.team
      sign_in_as(membership.user)

      delete "/api/v1/me", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(team.reload.deleted_at).to be_present
    end

    it "fails if they are the only owner of a team with more members" do
      owner = create(:membership, :owner)
      create(:membership, team: owner.team)
      sign_in_as(owner.user)

      delete "/api/v1/me", headers: csrf_headers

      expect(response).to have_http_status(:conflict)
      expect(User.where(id: owner.user.id).first).to be_present
    end

    it "does not fail if there is another owner" do
      owner_a = create(:membership, :owner)
      create(:membership, :owner, team: owner_a.team)
      sign_in_as(owner_a.user)

      delete "/api/v1/me", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /api/v1/auth/logout" do
    it "invalidates the session" do
      user = create(:user)
      sign_in_as(user)

      post "/api/v1/auth/logout", headers: csrf_headers

      expect(response).to have_http_status(:no_content)

      get "/api/v1/me"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GitHub login (RF-AUTH-004)" do
    it "redirects to GitHub with a signed state" do
      get "/api/v1/auth/github"

      expect(response).to have_http_status(:found)
      expect(response.location).to start_with("https://github.com/login/oauth/authorize")
    end

    it "creates the user and opens a session in the callback" do
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

    it "rejects an invalid state" do
      get "/api/v1/auth/github/callback", params: { code: "abc123", state: "not-a-real-state" }

      expect(response).to have_http_status(:bad_request)
    end

    describe "linking GitHub to the signed-in account (RF-TEAM-014)" do
      around do |example|
        original_app_url = ENV["APP_URL"]
        ENV["APP_URL"] = "http://localhost:3000"
        example.run
        ENV["APP_URL"] = original_app_url
      end

      def stub_github_profile(id:, login:)
        stub_request(:post, "https://github.com/login/oauth/access_token")
          .to_return(status: 200, body: { access_token: "gh_token_123" }.to_json, headers: { "Content-Type" => "application/json" })
        stub_request(:get, "https://api.github.com/user")
          .to_return(status: 200, body: { id: id, login: login, name: "Ada", email: "otra@github.example.com", avatar_url: "https://avatars/ada.png" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      def link_state
        get "/api/v1/auth/github", params: { link: 1, return_to: "/onboarding" }
        Rack::Utils.parse_query(URI.parse(response.location).query)["state"]
      end

      it "adds the identity to the session's account even if the email does not match" do
        user = create(:user, email: "ada@example.com")
        sign_in_as(user)
        stub_github_profile(id: 4242, login: "ada-gh")

        get "/api/v1/auth/github/callback", params: { code: "abc123", state: link_state }

        expect(response.location).to eq("http://localhost:3000/onboarding?github_link=linked")
        expect(user.reload.github_login).to eq("ada-gh")
        expect(user.github_uid).to eq(4242)
        expect(User.count).to eq(1)
      end

      it "keeps the invite code when coming back" do
        user = create(:user)
        sign_in_as(user)
        stub_github_profile(id: 4242, login: "ada-gh")
        get "/api/v1/auth/github", params: { link: 1, return_to: "/onboarding?code=ABCD-2345" }
        state = Rack::Utils.parse_query(URI.parse(response.location).query)["state"]

        get "/api/v1/auth/github/callback", params: { code: "abc123", state: state }

        expect(response.location).to eq("http://localhost:3000/onboarding?code=ABCD-2345&github_link=linked")
      end

      it "does not allow going back to another path, host or parameter" do
        sign_in_as(create(:user))
        stub_github_profile(id: 4242, login: "ada-gh")

        [ "https://evil.example/onboarding", "//evil.example/onboarding", "/t/x/settings", "/onboarding?next=/x",
          "/onboarding?code=<script>" ].each do |return_to|
          get "/api/v1/auth/github", params: { link: 1, return_to: return_to }
          state = Rack::Utils.parse_query(URI.parse(response.location).query)["state"]
          get "/api/v1/auth/github/callback", params: { code: "abc123", state: state }

          expect(response.location).to start_with("http://localhost:3000/onboarding?github_link=")
        end
      end

      it "does not steal it if it already belongs to another account" do
        create(:user, github_uid: 4242, github_login: "ada-gh")
        user = create(:user)
        sign_in_as(user)
        stub_github_profile(id: 4242, login: "ada-gh")

        get "/api/v1/auth/github/callback", params: { code: "abc123", state: link_state }

        expect(response.location).to eq("http://localhost:3000/onboarding?github_link=taken")
        expect(user.reload.github_uid).to be_nil
      end

      it "requires a session to ask for the link" do
        get "/api/v1/auth/github", params: { link: 1 }

        expect(response).to have_http_status(:unauthorized)
      end

      it "does not link if the callback session belongs to another account" do
        user = create(:user)
        sign_in_as(user)
        state = link_state
        sign_in_as(create(:user))
        stub_github_profile(id: 4242, login: "ada-gh")

        get "/api/v1/auth/github/callback", params: { code: "abc123", state: state }

        expect(response.location).to eq("http://localhost:3000/onboarding?github_link=error")
        expect(User.where(github_uid: 4242).exists?).to be false
      end
    end
  end

  describe "Google login (RF-AUTH-008)" do
    it "validates the id_token (signature, iss, aud, nonce, email_verified)" do
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

    it "stores the Google photo and updates it on every login (RF-AUTH-011)" do
      rsa_key = OpenSSL::PKey::RSA.generate(2048)
      jwk = JWT::JWK.new(rsa_key, { kid: "test-kid" })
      stub_request(:get, "https://www.googleapis.com/oauth2/v3/certs")
        .to_return(status: 200, body: { keys: [ jwk.export ] }.to_json, headers: { "Content-Type" => "application/json" })

      login_with_picture = lambda do |picture|
        get "/api/v1/auth/google"
        query = Rack::Utils.parse_query(URI.parse(response.location).query)
        id_token = JWT.encode(
          {
            iss: "https://accounts.google.com", aud: ENV.fetch("GOOGLE_CLIENT_ID", ""),
            sub: "google-sub-2", email: "grace@gmail.example.com", email_verified: true,
            nonce: query["nonce"], name: "Grace Hopper", picture: picture,
            exp: 10.minutes.from_now.to_i
          },
          rsa_key, "RS256", { kid: "test-kid" }
        )
        stub_request(:post, "https://oauth2.googleapis.com/token")
          .to_return(status: 200, body: { id_token: id_token }.to_json, headers: { "Content-Type" => "application/json" })
        get "/api/v1/auth/google/callback", params: { code: "abc123", state: query["state"] }
      end

      login_with_picture.call("https://lh3.example/old.png")
      expect(User.where(google_sub: "google-sub-2").first.avatar_url).to eq("https://lh3.example/old.png")

      login_with_picture.call("https://lh3.example/new.png")
      expect(User.where(google_sub: "google-sub-2").first.avatar_url).to eq("https://lh3.example/new.png")
    end
  end
end
