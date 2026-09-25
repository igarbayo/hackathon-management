# Installation tokens are cached in Redis and never in Mongo (RNF-GH-001).
# GitHub issues them valid for 1h; they are cached for ~55 min.
module Github
  class InstallationToken
    CACHE_TTL = 55.minutes.to_i

    def self.fetch(installation_id)
      cached = Sidekiq.redis { |conn| conn.call("GET", cache_key(installation_id)) }
      return cached if cached

      token = request_new_token(installation_id)
      Sidekiq.redis { |conn| conn.call("SET", cache_key(installation_id), token, "EX", CACHE_TTL.to_s) }
      token
    end

    def self.cache_key(installation_id)
      "gh_installation_token:#{installation_id}"
    end
    private_class_method :cache_key

    def self.request_new_token(installation_id)
      response = connection.post("/app/installations/#{installation_id}/access_tokens") do |req|
        req.headers["Authorization"] = "Bearer #{Github::AppJwt.generate}"
      end

      raise "Could not create the installation token: #{response.status}" unless response.success?

      response.body["token"]
    end
    private_class_method :request_new_token

    def self.connection
      Faraday.new(url: "https://api.github.com") do |f|
        f.headers["Accept"] = "application/vnd.github+json"
        f.headers["X-GitHub-Api-Version"] = "2022-11-28"
        f.response :json, content_type: /\bjson\b/
        f.adapter Faraday.default_adapter
      end
    end
    private_class_method :connection
  end
end
