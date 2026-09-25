# Cliente de la API REST de GitHub autenticado con un installation token
# (07-integracion-github.md). RNF-GH-002: deja un margen del 20% sobre el
# rate limit de GitHub antes de frenar en vez de agotarlo.
module Github
  class Client
    class RateLimited < StandardError
      attr_reader :reset_at

      def initialize(reset_at)
        @reset_at = reset_at
        super("rate limit de GitHub casi agotado, reintentar después de #{reset_at}")
      end
    end

    class NotFound < StandardError; end

    def initialize(installation_id)
      @installation_id = installation_id
    end

    def repositories
      paginate("/installation/repositories", key: "repositories")
    end

    def commit(full_name, sha)
      get("/repos/#{full_name}/commits/#{sha}")
    end

    def compare(full_name, base, head)
      get("/repos/#{full_name}/compare/#{base}...#{head}")
    end

    def pull_request_files(full_name, number)
      paginate("/repos/#{full_name}/pulls/#{number}/files")
    end

    def branches(full_name)
      paginate("/repos/#{full_name}/branches")
    end

    def get_commits(full_name, sha:, since:)
      paginate("/repos/#{full_name}/commits", params: { per_page: 100, sha: sha, since: since.iso8601 })
    end

    def pull_requests(full_name, state: "open")
      paginate("/repos/#{full_name}/pulls", params: { per_page: 100, state: state })
    end

    private

    attr_reader :installation_id

    def get(path, params = {})
      response = connection.get(path, params)
      handle_rate_limit(response)
      raise NotFound, path if response.status == 404
      raise "GitHub respondió #{response.status} en #{path}" unless response.success?

      response.body
    end

    def paginate(path, key: nil, params: { per_page: 100 })
      page = 1
      results = []

      loop do
        body = get(path, params.merge(page: page))
        items = key ? body[key] : body
        results.concat(items)
        break if items.size < params[:per_page].to_i

        page += 1
      end

      results
    end

    def handle_rate_limit(response)
      remaining = response.headers["x-ratelimit-remaining"]&.to_i
      limit = response.headers["x-ratelimit-limit"]&.to_i
      return unless remaining && limit && limit.positive?

      return unless remaining < limit * 0.2

      reset_at = Time.at(response.headers["x-ratelimit-reset"].to_i)
      raise RateLimited, reset_at
    end

    def connection
      Faraday.new(url: "https://api.github.com") do |f|
        f.headers["Authorization"] = "Bearer #{Github::InstallationToken.fetch(installation_id)}"
        f.headers["Accept"] = "application/vnd.github+json"
        f.headers["X-GitHub-Api-Version"] = "2022-11-28"
        f.response :json, content_type: /\bjson\b/
        f.adapter Faraday.default_adapter
      end
    end
  end
end
