require "rails_helper"

RSpec.describe "Arguments (pros y contras)", type: :request do
  describe "POST .../features/:key/arguments" do
    it "añade un pro" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments",
           params: { kind: "pro", text: "Más rápido" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(feature.reload.arguments.size).to eq(1)
    end
  end

  describe "PATCH .../arguments/:id" do
    it "solo el autor puede editar el texto" do
      membership = create(:membership)
      other = create(:membership, team: membership.team)
      feature = create(:feature, team: membership.team)
      argument = feature.arguments.create!(kind: "pro", text: "Original", author_id: membership.user_id)
      sign_in_as(other.user)

      patch "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}",
            params: { text: "Cambiado" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE .../arguments/:id" do
    it "el autor puede borrar su argumento" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      argument = feature.arguments.create!(kind: "con", text: "Riesgo", author_id: membership.user_id)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
    end

    it "un owner puede borrar el argumento de otro" do
      owner = create(:membership, :owner)
      author = create(:membership, team: owner.team)
      feature = create(:feature, team: owner.team)
      argument = feature.arguments.create!(kind: "con", text: "Riesgo", author_id: author.user_id)
      sign_in_as(owner.user)

      delete "/api/v1/teams/#{owner.team.id}/features/#{feature.key}/arguments/#{argument.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "PUT/DELETE .../arguments/:id/vote" do
    it "vota de forma idempotente" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      argument = feature.arguments.create!(kind: "pro", text: "Bien", author_id: membership.user_id)
      sign_in_as(membership.user)
      headers = csrf_headers

      put "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}/vote", headers: headers
      put "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}/vote", headers: headers

      expect(json_response["votes"]).to eq(1)
    end

    it "quita el voto" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      argument = feature.arguments.create!(kind: "pro", text: "Bien", author_id: membership.user_id, voter_ids: [ membership.user_id ])
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}/vote", headers: csrf_headers

      expect(json_response["votes"]).to eq(0)
    end
  end
end
