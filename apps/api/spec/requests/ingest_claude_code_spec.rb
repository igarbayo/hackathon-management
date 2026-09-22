require "rails_helper"

RSpec.describe "POST /api/v1/ingest/claude_code", type: :request do
  let(:membership) { create(:membership) }
  let(:raw_token) { "hb_mt_test123" }

  before do
    membership.update!(claude_code_attributes: { token_digest: Digest::SHA256.hexdigest(raw_token), token_prefix: raw_token[0, 12], privacy_level: "metadata" })
    create(:repository, team: membership.team, remote_urls: ["github.com/hackboard/repo"])
  end

  it "401 sin Authorization" do
    post "/api/v1/ingest/claude_code", params: { cli_version: "0.1.0", events: [] }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "acepta un lote válido sin exigir CSRF (autenticado por token, no por cookie)" do
    body = {
      cli_version: "0.3.1",
      events: [
        {
          client_event_id: "e1", kind: "cc_turn", occurred_at: Time.current.iso8601, session_ref: "s1",
          repo: { remote: "github.com/hackboard/repo" }, data: { tool_uses: 1 }
        }
      ]
    }

    post "/api/v1/ingest/claude_code", params: body, headers: { "Authorization" => "Bearer #{raw_token}" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response["accepted"]).to eq(1)
  end

  it "actor siempre es el dueño del token, sin excepciones" do
    body = {
      cli_version: "0.3.1",
      events: [{ client_event_id: "e2", kind: "system_test", occurred_at: Time.current.iso8601, session_ref: "s1", repo: { remote: "github.com/hackboard/repo" }, data: {} }]
    }

    post "/api/v1/ingest/claude_code", params: body, headers: { "Authorization" => "Bearer #{raw_token}" }, as: :json
    perform_enqueued_ingest_jobs

    created = ActivityEvent.where(dedupe_key: "cc:e2").first
    expect(created.actor["membership_id"]).to eq(membership.id.to_s)
  end

  it "aplica rate limit de 120 peticiones por minuto por token (RNF-SEC-005)" do
    body = { cli_version: "0.3.1", events: [] }

    120.times do
      post "/api/v1/ingest/claude_code", params: body, headers: { "Authorization" => "Bearer #{raw_token}" }, as: :json
    end

    post "/api/v1/ingest/claude_code", params: body, headers: { "Authorization" => "Bearer #{raw_token}" }, as: :json

    expect(response).to have_http_status(:too_many_requests)
  end

  def perform_enqueued_ingest_jobs
    Ingest::ProcessBatchJob.drain
  end
end
