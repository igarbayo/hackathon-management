require "rails_helper"

RSpec.describe "Activity claims (RF-ACT-018)", type: :request do
  let(:team) { create(:team) }
  let(:member) { create(:membership, team: team, display_name: "Ana") }
  let(:owner) { create(:membership, :owner, team: team, display_name: "Olga") }

  def commit(**actor)
    actor = actor.transform_keys(&:to_s)
    create(:activity_event, :github_commit, team: team,
           actor: { "user_id" => nil, "membership_id" => nil, "display" => actor["author_name"] }.merge(actor))
  end

  def claim(as:, **body)
    sign_in_as(as.user)
    post "/api/v1/teams/#{team.id}/activity/claim", params: body, headers: csrf_headers, as: :json
  end

  describe "GET /activity/unlinked_authors" do
    it "groups GitHub events with no user by login, with their email" do
      2.times { commit("github_login" => "ana-dev", "email" => "ana@uni.es", "author_name" => "Ana D") }
      commit("email" => "sinlogin@example.com", "author_name" => "No Login")
      commit("github_login" => "already", "user_id" => member.user_id.to_s, "membership_id" => member.id.to_s)
      sign_in_as(member.user)

      get "/api/v1/teams/#{team.id}/activity/unlinked_authors"

      expect(json_response["data"]).to eq([
        { "github_login" => "ana-dev", "email" => "ana@uni.es", "author_name" => "Ana D", "event_count" => 2, "last_event_at" => json_response["data"][0]["last_event_at"] },
        { "github_login" => nil, "email" => "sinlogin@example.com", "author_name" => "No Login", "event_count" => 1, "last_event_at" => json_response["data"][1]["last_event_at"] }
      ])
    end

    it "isolates by team (RNF-SEC-001)" do
      sign_in_as(create(:membership).user)

      get "/api/v1/teams/#{team.id}/activity/unlinked_authors"

      expect(response).to have_http_status(:not_found)
    end

    it "cannot be read with a token, even with the read scope" do
      result = Pat::Create.call(membership: member, name: "observe", preset: "observe")

      get "/api/v1/teams/#{team.id}/activity/unlinked_authors", headers: { "Authorization" => "Bearer #{result.raw_token}" }

      expect(response).to have_http_status(:forbidden)
      expect(json_response.dig("error", "code")).to eq("session_required")
    end
  end

  describe "GET /activity?actor_status=unlinked" do
    it "returns only GitHub events with no user and does not expose the author's email" do
      unlinked = commit("github_login" => "ana-dev", "email" => "ana@uni.es")
      commit("github_login" => "x", "user_id" => member.user_id.to_s)
      sign_in_as(member.user)

      get "/api/v1/teams/#{team.id}/activity", params: { actor_status: "unlinked" }

      expect(json_response["data"].map { |e| e["id"] }).to eq([ unlinked.id.to_s ])
      expect(json_response["data"][0]["actor"]).not_to have_key("email")
    end
  end

  describe "POST /activity/claim" do
    it "'These are mine' assigns the chosen events to yourself, marked as manual" do
      event = commit("github_login" => "ana-dev", "author_name" => "Ana D")

      claim(as: member, event_ids: [ event.id.to_s ], include_future: false)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"][0]["actor"]).to include("membership_id" => member.id.to_s, "display" => "Ana", "mapped_by" => "manual")
      expect(member.reload.git_identities).to be_empty
    end

    it "with include_future stores the identity and assigns the rest of that author's events" do
      chosen = commit("github_login" => "ana-dev", "email" => "ana@uni.es")
      rest = commit("email" => "ana@uni.es")

      claim(as: member, event_ids: [ chosen.id.to_s ], include_future: true)

      expect(member.reload.git_identities).to contain_exactly("ana-dev", "ana@uni.es")
      expect(rest.reload.actor["membership_id"]).to eq(member.id.to_s)

      later = Github::MapAuthor.call(team: team, login: nil, email: "ANA@uni.es", display_name: "Ana")
      expect(later["membership_id"]).to eq(member.id.to_s)
    end

    it "by author assigns all their events with no user" do
      events = 3.times.map { commit("github_login" => "ana-dev") }

      claim(as: member, author: { github_login: "ANA-dev" }, include_future: true)

      expect(json_response["data"].size).to eq(3)
      events.each { |e| expect(e.reload.actor["mapped_by"]).to eq("manual") }
    end

    it "a member cannot take events that already belong to someone else" do
      event = commit("github_login" => "olga", "user_id" => owner.user_id.to_s, "membership_id" => owner.id.to_s)

      claim(as: member, event_ids: [ event.id.to_s ], include_future: false)

      expect(json_response["data"]).to be_empty
      expect(json_response["skipped"]).to eq(1)
      expect(event.reload.actor["membership_id"]).to eq(owner.id.to_s)
    end

    it "a member cannot assign to someone else" do
      event = commit("github_login" => "x")

      claim(as: member, event_ids: [ event.id.to_s ], membership_id: owner.id.to_s, include_future: false)

      expect(response).to have_http_status(:forbidden)
    end

    it "an owner can assign any event to any member" do
      event = commit("github_login" => "x", "user_id" => owner.user_id.to_s, "membership_id" => owner.id.to_s)

      claim(as: owner, event_ids: [ event.id.to_s ], membership_id: member.id.to_s, include_future: false)

      expect(response).to have_http_status(:ok)
      expect(event.reload.actor).to include("membership_id" => member.id.to_s, "mapped_by" => "manual")
    end

    it "409 identity_taken if the identity already belongs to another member" do
      owner.update!(git_identities: [ "ana@uni.es" ])
      event = commit("email" => "ana@uni.es")

      claim(as: member, event_ids: [ event.id.to_s ], include_future: true)

      expect(response).to have_http_status(:conflict)
      expect(json_response.dig("error", "details", "code")).to eq("identity_taken")
      expect(event.reload.actor["user_id"]).to be_nil
    end

    it "ignores events from other teams (RNF-SEC-001)" do
      foreign = create(:activity_event, :github_commit, actor: { "user_id" => nil, "github_login" => "x" })

      claim(as: member, event_ids: [ foreign.id.to_s ], include_future: false)

      expect(json_response["data"]).to be_empty
      expect(foreign.reload.actor["user_id"]).to be_nil
    end

    it "does not accept more than 100 events" do
      claim(as: member, event_ids: Array.new(101) { BSON::ObjectId.new.to_s }, include_future: false)

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /activity/unclaim" do
    it "'Not mine' leaves the event with no user, removes the identity and is not reassigned by itself" do
      member.update!(git_identities: [ "ana@uni.es" ])
      event = commit("email" => "ana@uni.es", "author_name" => "Ana D", "user_id" => member.user_id.to_s,
                     "membership_id" => member.id.to_s, "display" => "Ana", "mapped_by" => "auto")
      sign_in_as(member.user)

      post "/api/v1/teams/#{team.id}/activity/unclaim", params: { event_ids: [ event.id.to_s ] }, headers: csrf_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(event.reload.actor).to include("user_id" => nil, "display" => "Ana D", "unclaimed_by" => [ member.id.to_s ])
      expect(event.actor).not_to have_key("mapped_by")
      expect(member.reload.git_identities).to be_empty

      Activity::ClaimForMembership.call(member, identities: [ "ana@uni.es" ])
      expect(event.reload.actor["user_id"]).to be_nil
    end

    it "a member cannot unassign someone else's events; an owner can" do
      event = commit("github_login" => "ana-dev", "user_id" => member.user_id.to_s, "membership_id" => member.id.to_s)
      other = create(:membership, team: team)
      sign_in_as(other.user)

      post "/api/v1/teams/#{team.id}/activity/unclaim", params: { event_ids: [ event.id.to_s ] }, headers: csrf_headers, as: :json
      expect(json_response["skipped"]).to eq(1)
      expect(event.reload.actor["membership_id"]).to eq(member.id.to_s)

      sign_in_as(owner.user)
      post "/api/v1/teams/#{team.id}/activity/unclaim", params: { event_ids: [ event.id.to_s ] }, headers: csrf_headers, as: :json
      expect(event.reload.actor["membership_id"]).to be_nil
    end
  end
end
