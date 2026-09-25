# "Paste a repo and done" (RF-GH-020). If any of the team's installations
# already has access, it links right away; if not, the App needs to be
# installed.
module Github
  class LinkRepository
    Result = Struct.new(:linked, :repository, :install_url, keyword_init: true)

    def self.call(team:, user:, full_name:, return_to: nil)
      new(team: team, user: user, full_name: full_name, return_to: return_to).call
    end

    def initialize(team:, user:, full_name:, return_to: nil)
      @team = team
      @user = user
      @full_name = full_name
      @return_to = return_to
    end

    def call
      match = find_accessible_repo

      if match
        Result.new(linked: true, repository: create_repository(match))
      else
        state = Github::InstallState.generate(team: team, user: user, pasted_full_name: full_name, return_to: return_to)
        Result.new(linked: false, install_url: "https://github.com/apps/#{ENV.fetch('GITHUB_APP_SLUG', '')}/installations/new?state=#{state}")
      end
    end

    private

    attr_reader :team, :user, :full_name, :return_to

    def find_accessible_repo
      Github::AvailableRepos.call(team).find { |r| r["full_name"].casecmp?(full_name) }
    end

    def create_repository(match)
      ::Repository.create!(
        team: team, github_repo_id: match["id"], full_name: match["full_name"],
        default_branch: match["default_branch"], installation_id: match["installation_id"],
        remote_urls: [ "github.com/#{match['full_name']}" ]
      )
    end
  end
end
