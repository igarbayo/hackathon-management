require "rails_helper"

RSpec.describe "MCP read tools" do
  let(:membership) { create(:membership) }
  let(:team) { membership.team }
  let(:resolved_token) { Tokens::Resolve.call(Pat::Create.call(membership: membership, name: "t", preset: "full").raw_token) }

  def call(tool, args = {})
    tool.call(team: team, membership: membership, resolved_token: resolved_token, args: args)
  end

  describe Mcp::Tools::Whoami do
    it "returns the team, the member and the scopes" do
      result = call(described_class)
      expect(result[:team][:id]).to eq(team.id.to_s)
      expect(result[:scopes]).to include("read")
    end
  end

  describe Mcp::Tools::GetTeamStatus do
    it "includes features by status, overdue and alerts" do
      create(:feature, team: team, status: "in_progress", deadline: 1.day.ago)

      result = call(described_class)

      expect(result[:features_by_status]).to have_key("in_progress")
      expect(result[:overdue_features]).not_to be_empty
      expect(result[:deterministic_alerts]).to be_an(Array)
    end
  end

  describe Mcp::Tools::ListFeatures do
    it "filters by mine" do
      mine = create(:feature, team: team, assignee_ids: [ membership.id ])
      create(:feature, team: team)

      result = call(described_class, { "mine" => true })

      expect(result[:features].map { |f| f[:key] }).to eq([ mine.key ])
    end

    it "mine returns an error for an integration token" do
      integration_token = Integration::Create.call(team: team, created_by: membership.user, name: "Bot", scopes: [ "read" ])
      resolved = Tokens::Resolve.call(integration_token.raw_token)

      expect { described_class.call(team: team, membership: nil, resolved_token: resolved, args: { "mine" => true }) }
        .to raise_error(Mcp::ToolError)
    end

    it "filters by objective_key" do
      objective = create(:objective, team: team)
      feature = create(:feature, team: team, objective_ids: [ objective.id ])
      create(:feature, team: team)

      result = call(described_class, { "objective_key" => objective.key })

      expect(result[:features].map { |f| f[:key] }).to eq([ feature.key ])
    end
  end

  describe Mcp::Tools::GetFeature do
    it "returns an actionable ToolError if it does not exist" do
      expect { call(described_class, { "key" => "F-999" }) }.to raise_error(Mcp::ToolError, /F-999/)
    end

    it "includes arguments and recent events" do
      feature = create(:feature, team: team)
      feature.arguments.create!(kind: "pro", text: "good", author_id: membership.user_id)

      result = call(described_class, { "key" => feature.key })

      expect(result[:arguments].size).to eq(1)
    end
  end

  describe Mcp::Tools::ListObjectives do
    it "includes the coverage from the latest analysis if there is one" do
      objective = create(:objective, team: team)
      create(:ai_analysis, team: team, status: "succeeded", result: { "coverage" => [ { "objective_key" => objective.key, "status" => "covered" } ] })

      result = call(described_class)

      expect(result[:objectives].find { |o| o[:key] == objective.key }[:coverage]).to eq("covered")
    end
  end

  describe Mcp::Tools::SuggestBranchName do
    it "generates f-<number>-title-in-kebab-case" do
      feature = create(:feature, team: team, title: "Login with GitHub")

      result = call(described_class, { "feature_key" => feature.key })

      expect(result[:branch_name]).to eq("#{feature.key.downcase}-login-with-github")
    end
  end

  describe Mcp::Tools::ListActivity do
    it "respects the maximum limit of 50" do
      create(:activity_event, team: team, source: "system", kind: "member_joined", dedupe_key: "s1")

      result = call(described_class, { "limit" => 500 })

      expect(result[:events].size).to be <= 50
    end

    it "resolves member as \"me\"" do
      create(:activity_event, team: team, source: "system", kind: "member_joined", dedupe_key: "s1", actor: { "user_id" => membership.user_id.to_s })

      result = call(described_class, { "member" => "me" })

      expect(result[:events]).not_to be_empty
    end
  end
end
