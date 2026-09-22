# Repos accesibles por las instalaciones del equipo, con caché de 5 min
# (RF-GH-020, RF-GH-003).
module Github
  class AvailableRepos
    CACHE_TTL = 5.minutes

    def self.call(team)
      team.github_installation_ids.flat_map { |installation_id| repos_for(installation_id) }
    end

    def self.repos_for(installation_id)
      Rails.cache.fetch("github_repos:#{installation_id}", expires_in: CACHE_TTL) do
        Github::Client.new(installation_id).repositories.map do |repo|
          { "id" => repo["id"], "full_name" => repo["full_name"], "default_branch" => repo["default_branch"], "installation_id" => installation_id }
        end
      end
    end
  end
end
