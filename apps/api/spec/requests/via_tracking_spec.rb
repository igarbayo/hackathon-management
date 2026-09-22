require "rails_helper"

# RF-API-006: toda escritura hecha con un token deja rastro en el feed con
# `via`. Las mismas escrituras hechas desde la web no lo llevan.
RSpec.describe "Trazabilidad via (RF-API-006)", type: :request do
  def token_for(membership, preset: "completo")
    Pat::Create.call(membership: membership, name: "Agente", preset: preset).raw_token
  end

  it "crear un objetivo con un token deja un evento system/api_change con via" do
    membership = create(:membership)
    token = token_for(membership)

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "Nuevo", priority: "must" }, headers: { "Authorization" => "Bearer #{token}" }, as: :json

    event = ActivityEvent.where(team_id: membership.team.id, kind: "api_change").first
    expect(event).to be_present
    expect(event.via["channel"]).to eq("api")
    expect(event.via["token_kind"]).to eq("pat")
    expect(event.payload["fields"]).to match_array(%w[title priority])
  end

  it "crear el mismo objetivo desde la web (sesión) no deja ningún api_change" do
    membership = create(:membership)
    sign_in_as(membership.user)

    post "/api/v1/teams/#{membership.team.id}/objectives", params: { title: "Nuevo", priority: "must" }, headers: csrf_headers, as: :json

    expect(ActivityEvent.where(team_id: membership.team.id, kind: "api_change").count).to eq(0)
  end

  it "cambiar el status de una feature con un token deja el evento feature_status_changed con via, no un api_change aparte" do
    membership = create(:membership)
    feature = create(:feature, team: membership.team, status: "idea")
    token = token_for(membership)

    patch "/api/v1/teams/#{membership.team.id}/features/#{feature.key}", params: { status: "in_progress" },
                                                                          headers: { "Authorization" => "Bearer #{token}" }, as: :json

    status_event = ActivityEvent.where(team_id: membership.team.id, kind: "feature_status_changed").first
    expect(status_event.via["token_kind"]).to eq("pat")
    expect(ActivityEvent.where(team_id: membership.team.id, kind: "api_change").count).to eq(0)
  end

  it "editar el título y el status a la vez deja los dos eventos, cada uno con su via" do
    membership = create(:membership)
    feature = create(:feature, team: membership.team, status: "idea")
    token = token_for(membership)

    patch "/api/v1/teams/#{membership.team.id}/features/#{feature.key}", params: { status: "in_progress", title: "Nuevo título" },
                                                                          headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(ActivityEvent.where(team_id: membership.team.id, kind: "feature_status_changed").count).to eq(1)
    api_change = ActivityEvent.where(team_id: membership.team.id, kind: "api_change").first
    expect(api_change.payload["fields"]).to eq([ "title" ])
  end

  it "votar un argumento con un token deja constancia" do
    membership = create(:membership)
    feature = create(:feature, team: membership.team)
    argument = feature.arguments.create!(kind: "pro", text: "Buena idea", author_id: membership.user_id)
    token = token_for(membership)

    put "/api/v1/teams/#{membership.team.id}/features/#{feature.key}/arguments/#{argument.id}/vote",
        headers: { "Authorization" => "Bearer #{token}" }

    event = ActivityEvent.where(team_id: membership.team.id, kind: "api_change").first
    expect(event.payload["entity"]).to eq("argument")
    expect(event.via["token_prefix"]).to be_present
  end
end
