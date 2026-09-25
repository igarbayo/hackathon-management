module Auth
  class GithubLogin
    AuthorizationFailed = Class.new(StandardError)

    AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
    TOKEN_URL = "https://github.com/login/oauth/access_token"
    API_BASE = "https://api.github.com"

    def self.authorize_url(state:)
      params = {
        client_id: ENV.fetch("GITHUB_CLIENT_ID", ""),
        redirect_uri: callback_url,
        scope: "read:user user:email",
        state: state
      }
      "#{AUTHORIZE_URL}?#{params.to_query}"
    end

    def self.callback_url
      "#{ENV.fetch('API_URL', '')}/api/v1/auth/github/callback"
    end

    def self.call(code:)
      access_token = exchange_code(code)
      profile = fetch_profile(access_token)
      email = profile["email"] || fetch_primary_verified_email(access_token)

      find_or_create_user(profile, email)
    end

    def self.exchange_code(code)
      response = connection.post(TOKEN_URL) do |req|
        req.headers["Accept"] = "application/json"
        req.body = {
          client_id: ENV.fetch("GITHUB_CLIENT_ID", ""),
          client_secret: ENV.fetch("GITHUB_CLIENT_SECRET", ""),
          code: code,
          redirect_uri: callback_url
        }
      end

      token = response.body["access_token"]
      raise AuthorizationFailed, "GitHub did not return an access_token" if token.blank?

      token
    end
    private_class_method :exchange_code

    def self.fetch_profile(access_token)
      response = connection.get("#{API_BASE}/user") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end
      raise AuthorizationFailed, "could not read the GitHub profile" unless response.success?

      response.body
    end
    private_class_method :fetch_profile

    def self.fetch_primary_verified_email(access_token)
      response = connection.get("#{API_BASE}/user/emails") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end
      return nil unless response.success?

      primary = response.body.find { |e| e["primary"] && e["verified"] }
      primary && primary["email"]
    end
    private_class_method :fetch_primary_verified_email

    def self.find_or_create_user(profile, email)
      github_uid = profile["id"]
      github_login = profile["login"]

      user = User.where(github_uid: github_uid).first
      user ||= (email.present? ? User.where(email: email.downcase).first : nil)

      if user
        # RF-AUTH-011: the photo is the one from the last provider used to log
        # in.
        user.update!(github_uid: github_uid, github_login: github_login, avatar_url: profile["avatar_url"].presence || user.avatar_url)
      else
        user = User.create!(
          email: email || "#{github_login}@users.noreply.github.com",
          name: profile["name"].presence || github_login,
          github_uid: github_uid,
          github_login: github_login,
          avatar_url: profile["avatar_url"]
        )
      end

      user
    end
    private_class_method :find_or_create_user

    def self.connection
      Faraday.new do |f|
        f.request :url_encoded
        f.response :json, content_type: /\bjson\b/
        f.adapter Faraday.default_adapter
      end
    end
    private_class_method :connection
  end
end
