require "rails_helper"

RSpec.describe "GET /api/v1/openapi.json", type: :request do
  it "es pública, sin autenticación" do
    get "/api/v1/openapi.json"

    expect(response).to have_http_status(:ok)
    expect(json_response["openapi"]).to eq("3.1.0")
  end

  it "cada endpoint session_only está marcado como tal" do
    get "/api/v1/openapi.json"

    op = json_response["paths"]["/teams/{id}"]["patch"]
    expect(op["x-hackboard-access"]).to eq("session_only")
  end

  it "los endpoints de escritura llevan su scope" do
    get "/api/v1/openapi.json"

    create_op = json_response["paths"]["/teams/{team_id}/objectives"]["post"]
    expect(create_op["x-hackboard-scope"]).to eq("objectives:write")

    index_op = json_response["paths"]["/teams/{team_id}/objectives"]["get"]
    expect(index_op["x-hackboard-scope"]).to eq("read")
  end

  it "el borrado de una feature es session_only aunque el resto de acciones no lo sean" do
    get "/api/v1/openapi.json"

    feature_path = json_response["paths"]["/teams/{team_id}/features/{key}"]
    expect(feature_path["delete"]["x-hackboard-access"]).to eq("session_only")
    expect(feature_path["get"]["x-hackboard-scope"]).to eq("read")
  end

  it "incluye los endpoints solo-Bearer con su marca manual" do
    get "/api/v1/openapi.json"

    expect(json_response["paths"]["/mcp"]["post"]["x-hackboard-access"]).to eq("bearer")
    expect(json_response["paths"]["/ingest/claude_code"]["post"]["x-hackboard-access"]).to eq("bearer:ingest")
  end
end
