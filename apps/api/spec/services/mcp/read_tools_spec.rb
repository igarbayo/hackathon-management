require "rails_helper"

RSpec.describe "Herramientas MCP de lectura" do
  let(:membership) { create(:membership) }
  let(:team) { membership.team }
  let(:resolved_token) { Tokens::Resolve.call(Pat::Create.call(membership: membership, name: "t", preset: "completo").raw_token) }

  def call(tool, args = {})
    tool.call(team: team, membership: membership, resolved_token: resolved_token, args: args)
  end

  describe Mcp::Tools::Whoami do
    it "devuelve el equipo, el miembro y los scopes" do
      result = call(described_class)
      expect(result[:team][:id]).to eq(team.id.to_s)
      expect(result[:scopes]).to include("read")
    end
  end

  describe Mcp::Tools::GetTeamStatus do
    it "incluye features por estado, overdue y alertas" do
      create(:feature, team: team, status: "in_progress", deadline: 1.day.ago)

      result = call(described_class)

      expect(result[:features_by_status]).to have_key("in_progress")
      expect(result[:overdue_features]).not_to be_empty
      expect(result[:deterministic_alerts]).to be_an(Array)
    end
  end

  describe Mcp::Tools::ListFeatures do
    it "filtra por mine" do
      mine = create(:feature, team: team, assignee_ids: [ membership.id ])
      create(:feature, team: team)

      result = call(described_class, { "mine" => true })

      expect(result[:features].map { |f| f[:key] }).to eq([ mine.key ])
    end

    it "mine da error para un token de integración" do
      integration_token = Integration::Create.call(team: team, created_by: membership.user, name: "Bot", scopes: [ "read" ])
      resolved = Tokens::Resolve.call(integration_token.raw_token)

      expect { described_class.call(team: team, membership: nil, resolved_token: resolved, args: { "mine" => true }) }
        .to raise_error(Mcp::ToolError)
    end

    it "filtra por objective_key" do
      objective = create(:objective, team: team)
      feature = create(:feature, team: team, objective_ids: [ objective.id ])
      create(:feature, team: team)

      result = call(described_class, { "objective_key" => objective.key })

      expect(result[:features].map { |f| f[:key] }).to eq([ feature.key ])
    end
  end

  describe Mcp::Tools::GetFeature do
    it "da un ToolError accionable si no existe" do
      expect { call(described_class, { "key" => "F-999" }) }.to raise_error(Mcp::ToolError, /F-999/)
    end

    it "incluye argumentos y eventos recientes" do
      feature = create(:feature, team: team)
      feature.arguments.create!(kind: "pro", text: "bien", author_id: membership.user_id)

      result = call(described_class, { "key" => feature.key })

      expect(result[:arguments].size).to eq(1)
    end
  end

  describe Mcp::Tools::ListObjectives do
    it "incluye la cobertura del último análisis si existe" do
      objective = create(:objective, team: team)
      create(:ai_analysis, team: team, status: "succeeded", result: { "coverage" => [ { "objective_key" => objective.key, "status" => "covered" } ] })

      result = call(described_class)

      expect(result[:objectives].find { |o| o[:key] == objective.key }[:coverage]).to eq("covered")
    end
  end

  describe Mcp::Tools::SuggestBranchName do
    it "genera f-<numero>-titulo-en-kebab" do
      feature = create(:feature, team: team, title: "Login con GitHub")

      result = call(described_class, { "feature_key" => feature.key })

      expect(result[:branch_name]).to eq("#{feature.key.downcase}-login-con-github")
    end
  end

  describe Mcp::Tools::ListActivity do
    it "respeta el límite máximo de 50" do
      create(:activity_event, team: team, source: "system", kind: "member_joined", dedupe_key: "s1")

      result = call(described_class, { "limit" => 500 })

      expect(result[:events].size).to be <= 50
    end

    it "resuelve member como \"me\"" do
      create(:activity_event, team: team, source: "system", kind: "member_joined", dedupe_key: "s1", actor: { "user_id" => membership.user_id.to_s })

      result = call(described_class, { "member" => "me" })

      expect(result[:events]).not_to be_empty
    end
  end
end
