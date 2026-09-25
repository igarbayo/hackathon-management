require "rails_helper"

RSpec.describe "POST /api/v1/mcp", type: :request do
  def rpc(method, params = nil, id: 1)
    body = { jsonrpc: "2.0", method: method }
    body[:id] = id if id
    body[:params] = params if params
    body
  end

  it "401 without Authorization, with WWW-Authenticate pointing to the metadata" do
    post "/api/v1/mcp", params: rpc("tools/list"), as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["WWW-Authenticate"]).to include("resource_metadata=")
  end

  it "initialize returns protocolVersion, capabilities and an Mcp-Session-Id" do
    token = Pat::Create.call(membership: create(:membership), name: "Agente", preset: "full").raw_token

    post "/api/v1/mcp", params: rpc("initialize", { clientInfo: { name: "claude-code", version: "1.0" }, protocolVersion: "2025-06-18" }),
                         headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["result"]["protocolVersion"]).to be_present
    expect(json_response["result"]["capabilities"]).to have_key("tools")
    expect(response.headers["Mcp-Session-Id"]).to be_present
  end

  it "notifications/initialized (no id) gets no response" do
    token = Pat::Create.call(membership: create(:membership), name: "Agente", preset: "full").raw_token

    post "/api/v1/mcp", params: rpc("notifications/initialized", nil, id: nil), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(response).to have_http_status(:accepted)
    expect(response.body).to be_blank
  end

  it "tools/list only returns what the token can use" do
    token = Pat::Create.call(membership: create(:membership), name: "Read only", preset: "observe").raw_token

    post "/api/v1/mcp", params: rpc("tools/list"), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    names = json_response["result"]["tools"].map { |t| t["name"] }
    expect(names).to include("whoami", "list_features")
    expect(names).not_to include("create_feature", "report_progress")
  end

  it "tools/call for whoami works end to end" do
    membership = create(:membership)
    token = Pat::Create.call(membership: membership, name: "Agente", preset: "full").raw_token

    post "/api/v1/mcp", params: rpc("tools/call", { name: "whoami", arguments: {} }), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    text = JSON.parse(json_response["result"]["content"].first["text"])
    expect(text["kind"]).to eq("pat")
    expect(text["team"]["id"]).to eq(membership.team.id.to_s)
  end

  it "tools/call without the required scope returns a protocol error, not a call" do
    token = Pat::Create.call(membership: create(:membership), name: "Read only", preset: "observe").raw_token

    post "/api/v1/mcp", params: rpc("tools/call", { name: "create_feature", arguments: { title: "x" } }), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(json_response["error"]["code"]).to eq(-32000)
    expect(Feature.count).to eq(0)
  end

  it "a domain error inside the tool comes back as isError, not as a protocol error" do
    token = Pat::Create.call(membership: create(:membership), name: "Agente", preset: "full").raw_token

    post "/api/v1/mcp", params: rpc("tools/call", { name: "get_feature", arguments: { key: "F-999" } }), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["result"]["isError"]).to be true
    expect(json_response["result"]["content"].first["text"]).to include("F-999")
  end

  it "an unknown tool returns a protocol error" do
    token = Pat::Create.call(membership: create(:membership), name: "Agente", preset: "full").raw_token

    post "/api/v1/mcp", params: rpc("tools/call", { name: "no_existe", arguments: {} }), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(json_response["error"]["code"]).to eq(-32602)
  end

  it "applies the rate limit of 120/min per token" do
    token = Pat::Create.call(membership: create(:membership), name: "Agente", preset: "full").raw_token

    120.times { post "/api/v1/mcp", params: rpc("tools/list"), headers: { "Authorization" => "Bearer #{token}" }, as: :json }
    post "/api/v1/mcp", params: rpc("tools/list"), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(response).to have_http_status(:too_many_requests)
  end
end
