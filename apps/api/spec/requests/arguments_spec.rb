require "rails_helper"

RSpec.describe "Arguments (pros and cons)", type: :request do
  describe "POST .../features/:key/arguments" do
    it "adds a pro" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      sign_in_as(membership.user)

      post "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments",
           params: { kind: "pro", text: "Faster" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(feature.reload.arguments.size).to eq(1)
    end
  end

  describe "PATCH .../arguments/:id" do
    it "only the author can edit the text" do
      membership = create(:membership)
      other = create(:membership, team: membership.team)
      feature = create(:feature, team: membership.team)
      argument = feature.arguments.create!(kind: "pro", text: "Original", author_id: membership.user_id)
      sign_in_as(other.user)

      patch "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}",
            params: { text: "Changed" }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE .../arguments/:id" do
    it "the author can delete their argument" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      argument = feature.arguments.create!(kind: "con", text: "Risk", author_id: membership.user_id)
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
    end

    it "an owner can delete someone else's argument" do
      owner = create(:membership, :owner)
      author = create(:membership, team: owner.team)
      feature = create(:feature, team: owner.team)
      argument = feature.arguments.create!(kind: "con", text: "Risk", author_id: author.user_id)
      sign_in_as(owner.user)

      delete "/api/v1/teams/#{owner.team.id}/features/#{feature.key}/arguments/#{argument.id}", headers: csrf_headers

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "PUT/DELETE .../arguments/:id/vote" do
    it "votes idempotently" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      argument = feature.arguments.create!(kind: "pro", text: "Good", author_id: membership.user_id)
      sign_in_as(membership.user)
      headers = csrf_headers

      put "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}/vote", headers: headers
      put "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}/vote", headers: headers

      expect(json_response["votes"]).to eq(1)
    end

    it "removes the vote" do
      membership = create(:membership)
      feature = create(:feature, team: membership.team)
      argument = feature.arguments.create!(kind: "pro", text: "Good", author_id: membership.user_id, voter_ids: [ membership.user_id ])
      sign_in_as(membership.user)

      delete "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}/vote", headers: csrf_headers

      expect(json_response["votes"]).to eq(0)
    end
  end
end
