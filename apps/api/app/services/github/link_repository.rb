# "Pegar repo y listo" (RF-GH-020). Si alguna instalación del equipo ya
# tiene acceso, vincula al instante; si no, hay que instalar la App.
module Github
  class LinkRepository
    Result = Struct.new(:linked, :repository, :install_url, keyword_init: true)

    def self.call(team:, user:, full_name:)
      new(team: team, user: user, full_name: full_name).call
    end

    def initialize(team:, user:, full_name:)
      @team = team
      @user = user
      @full_name = full_name
    end

    def call
      match = find_accessible_repo

      if match
        Result.new(linked: true, repository: create_repository(match))
      else
        state = Github::InstallState.generate(team: team, user: user, pasted_full_name: full_name)
        Result.new(linked: false, install_url: "https://github.com/apps/#{ENV.fetch('GITHUB_APP_SLUG', '')}/installations/new?state=#{state}")
      end
    end

    private

    attr_reader :team, :user, :full_name

    def find_accessible_repo
      Github::AvailableRepos.call(team).find { |r| r["full_name"].casecmp?(full_name) }
    end

    def create_repository(match)
      ::Repository.create!(
        team: team, github_repo_id: match["id"], full_name: match["full_name"],
        default_branch: match["default_branch"], installation_id: match["installation_id"],
        remote_urls: ["github.com/#{match['full_name']}"]
      )
    end
  end
end
