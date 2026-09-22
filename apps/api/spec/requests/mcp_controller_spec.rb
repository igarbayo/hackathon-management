require "rails_helper"

RSpec.describe "POST /api/v1/mcp", type: :request do
  def rpc(method, params = nil, id: 1)
    body = { jsonrpc: "2.0", method: method }
    body[:id] = id if id
    body[:params] = params if params
    body
  end

  it "401 sin Authorization, con WWW-Authenticate apuntando a los metadatos" do
    post "/api/v1/mcp", params: rpc("tools/list"), as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["WWW-Authenticate"]).to include("resource_metadata=")
  end

  it "initialize devuelve protocolVersion, capabilities y un Mcp-Session-Id" do
    token = Pat::Create.call(membership: create(:membership), name: "Agente", preset: "completo").raw_token

    post "/api/v1/mcp", params: rpc("initialize", { clientInfo: { name: "claude-code", version: "1.0" }, protocolVersion: "2025-06-18" }),
                         headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["result"]["protocolVersion"]).to be_present
    expect(json_response["result"]["capabilities"]).to have_key("tools")
    expect(response.headers["Mcp-Session-Id"]).to be_present
  end

  it "notifications/initialized (sin id) no lleva respuesta" do
    token = Pat::Create.call(membership: create(:membership), name: "Agente", preset: "completo").raw_token

    post "/api/v1/mcp", params: rpc("notifications/initialized", nil, id: nil), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(response).to have_http_status(:accepted)
    expect(response.body).to be_blank
  end

  it "tools/list solo devuelve lo que el token puede usar" do
    token = Pat::Create.call(membership: create(:membership), name: "Solo lectura", preset: "observar").raw_token

    post "/api/v1/mcp", params: rpc("tools/list"), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    names = json_response["result"]["tools"].map { |t| t["name"] }
    expect(names).to include("whoami", "list_features")
    expect(names).not_to include("create_feature", "report_progress")
  end

  it "tools/call de whoami funciona de punta a punta" do
    membership = create(:membership)
    token = Pat::Create.call(membership: membership, name: "Agente", preset: "completo").raw_token

    post "/api/v1/mcp", params: rpc("tools/call", { name: "whoami", arguments: {} }), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    text = JSON.parse(json_response["result"]["content"].first["text"])
    expect(text["kind"]).to eq("pat")
    expect(text["team"]["id"]).to eq(membership.team.id.to_s)
  end

  it "tools/call sin el scope necesario da un error de protocolo, no una llamada" do
    token = Pat::Create.call(membership: create(:membership), name: "Solo lectura", preset: "observar").raw_token

    post "/api/v1/mcp", params: rpc("tools/call", { name: "create_feature", arguments: { title: "x" } }), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(json_response["error"]["code"]).to eq(-32000)
    expect(Feature.count).to eq(0)
  end

  it "un error de dominio dentro de la herramienta vuelve como isError, no como error de protocolo" do
    token = Pat::Create.call(membership: create(:membership), name: "Agente", preset: "completo").raw_token

    post "/api/v1/mcp", params: rpc("tools/call", { name: "get_feature", arguments: { key: "F-999" } }), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["result"]["isError"]).to be true
    expect(json_response["result"]["content"].first["text"]).to include("F-999")
  end

  it "herramienta desconocida da un error de protocolo" do
    token = Pat::Create.call(membership: create(:membership), name: "Agente", preset: "completo").raw_token

    post "/api/v1/mcp", params: rpc("tools/call", { name: "no_existe", arguments: {} }), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(json_response["error"]["code"]).to eq(-32602)
  end

  it "aplica el rate limit de 120/min por token" do
    token = Pat::Create.call(membership: create(:membership), name: "Agente", preset: "completo").raw_token

    120.times { post "/api/v1/mcp", params: rpc("tools/list"), headers: { "Authorization" => "Bearer #{token}" }, as: :json }
    post "/api/v1/mcp", params: rpc("tools/list"), headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(response).to have_http_status(:too_many_requests)
  end
end
