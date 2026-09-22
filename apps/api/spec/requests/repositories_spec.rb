require "rails_helper"

RSpec.describe "Repositories", type: :request do
  around do |example|
    original_id = ENV["GITHUB_APP_ID"]
    original_key = ENV["GITHUB_APP_PRIVATE_KEY"]
    ENV["GITHUB_APP_ID"] = "1"
    ENV["GITHUB_APP_PRIVATE_KEY"] = OpenSSL::PKey::RSA.generate(2048).to_pem
    example.run
    ENV["GITHUB_APP_ID"] = original_id
    ENV["GITHUB_APP_PRIVATE_KEY"] = original_key
  end

  describe "GET /api/v1/teams/:team_id/repositories" do
    it "lista solo los repos activos del equipo" do
      membership = create(:membership)
      active = create(:repository, team: membership.team, active: true)
      create(:repository, team: membership.team, active: false)
      sign_in_as(membership.user)

      get "/api/v1/teams/#{membership.team.id}/repositories"

      expect(json_response["data"].map { |r| r["id"] }).to eq([active.id.to_s])
    end
  end

  describe "POST /api/v1/teams/:team_id/repositories" do
    it "409 repo_already_linked si el repo ya está activo en otro equipo" do
      create(:repository, full_name: "org/repo", active: true)
      membership = create(:membership)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/repositories", params: { full_name: "org/repo" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json_response["error"]["details"]["code"]).to eq("repo_already_linked")
    end

    it "vincula el repo si alguna instalación del equipo tiene acceso" do
      membership = create(:membership)
      team = membership.team
      team.update!(github_installation_ids: [42])
      stub_request(:post, "https://api.github.com/app/installations/42/access_tokens")
        .to_return(status: 201, body: { token: "ghs_x" }.to_json, headers: { "Content-Type" => "application/json" })
      stub_request(:get, "https://api.github.com/installation/repositories").with(query: hash_including("per_page" => "100"))
        .to_return(status: 200, body: { repositories: [{ id: 1, full_name: "org/repo", default_branch: "main" }] }.to_json, headers: { "Content-Type" => "application/json" })
      sign_in_as(membership.user)

      post "/api/v1/teams/#{team.id}/repositories", params: { full_name: "org/repo" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["full_name"]).to eq("org/repo")
    end
  end

  describe "POST /api/v1/teams/:team_id/repositories/:id/resync" do
    it "relanza la importación del histórico" do
      membership = create(:membership)
      repository = create(:repository, team: membership.team)
      sign_in_as(membership.user)

      expect(Github::ImportHistoryJob).to receive(:perform_async).with(repository.id.to_s)

      post "/api/v1/teams/#{membership.team.id}/repositories/#{repository.id}/resync", headers: csrf_headers

      expect(response).to have_http_status(:accepted)
    end
  end

  describe "DELETE /api/v1/teams/:team_id/repositories/:id" do
    it "desactiva el repo sin borrar sus eventos" do
      membership = create(:membership)
      repository = create(:repository, team: membership.team)
      event = create(:activity_event, :github_commit, team: membership.team, repository: repository)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/repositories/#{repository.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
      expect(repository.reload.active).to be false
      expect(ActivityEvent.where(id: event.id).first).to be_present
    end
  end
end
