require "rails_helper"

RSpec.describe "MCP write tools" do
  let(:membership) { create(:membership) }
  let(:team) { membership.team }
  let(:resolved_token) { Tokens::Resolve.call(Pat::Create.call(membership: membership, name: "t", preset: "full").raw_token) }

  def call(tool, args = {}, membership_override: membership, resolved_token_override: resolved_token)
    tool.call(team: team, membership: membership_override, resolved_token: resolved_token_override, args: args)
  end

  describe Mcp::Tools::ReportProgress do
    it "creates an mcp/progress_report ActivityEvent with a confirmed attribution" do
      feature = create(:feature, team: team)

      result = call(described_class, { "feature_key" => feature.key, "summary" => "Login done" })

      event = ActivityEvent.where(id: result[:event_id]).first
      expect(event.source).to eq("mcp")
      expect(event.attribution.status).to eq("confirmed")
      expect(event.attribution.feature_id).to eq(feature.id)
    end

    it "does not change the feature's status (status_hint is only informational)" do
      feature = create(:feature, team: team, status: "idea")

      call(described_class, { "feature_key" => feature.key, "summary" => "x", "status_hint" => "started" })

      expect(feature.reload.status).to eq("idea")
    end

    it "limit of 30 a day per member and feature" do
      feature = create(:feature, team: team)
      30.times { call(described_class, { "feature_key" => feature.key, "summary" => "x" }) }

      expect { call(described_class, { "feature_key" => feature.key, "summary" => "x" }) }.to raise_error(Mcp::ToolError, /Daily limit/)
    end

    it "requires a person, not an integration" do
      expect { call(described_class, { "feature_key" => create(:feature, team: team).key, "summary" => "x" }, membership_override: nil) }
        .to raise_error(Mcp::ToolError, /member token or a person.s PAT/)
    end
  end

  describe Mcp::Tools::CreateFeature do
    it "creates the feature in idea and records it with via mcp" do
      result = call(described_class, { "title" => "New" })

      feature = Feature.where(id: result[:id]).first
      expect(feature.status).to eq("idea")
      event = ActivityEvent.where(kind: "feature_created").first
      expect(event.via["channel"]).to eq("mcp")
    end

    it "assign_to_me assigns the calling member" do
      result = call(described_class, { "title" => "New", "assign_to_me" => true })

      expect(Feature.where(id: result[:id]).first.assignee_ids.map(&:to_s)).to eq([ membership.id.to_s ])
    end

    it "idempotency_key: the second call returns the same result without creating another feature" do
      call(described_class, { "title" => "New", "idempotency_key" => "abc" })
      call(described_class, { "title" => "Another", "idempotency_key" => "abc" })

      expect(Feature.where(team_id: team.id).count).to eq(1)
    end

    it "invalid objective_keys returns an actionable ToolError" do
      expect { call(described_class, { "title" => "x", "objective_keys" => [ "O-999" ] }) }.to raise_error(Mcp::ToolError, /O-999/)
    end
  end

  describe Mcp::Tools::UpdateFeature do
    it "updates and returns the feature" do
      feature = create(:feature, team: team, title: "Old")

      result = call(described_class, { "key" => feature.key, "title" => "New" })

      expect(result[:title]).to eq("New")
    end

    it "a mismatched expected_updated_at returns a conflict with the current document" do
      feature = create(:feature, team: team)

      expect { call(described_class, { "key" => feature.key, "title" => "x", "expected_updated_at" => 1.day.ago.iso8601 }) }
        .to raise_error(Mcp::ToolError, /Conflict/)
    end
  end

  describe Mcp::Tools::MoveFeature do
    it "changes the status and fires the event" do
      feature = create(:feature, team: team, status: "idea")

      call(described_class, { "key" => feature.key, "status" => "in_progress" })

      expect(feature.reload.status).to eq("in_progress")
      expect(ActivityEvent.where(kind: "feature_status_changed").count).to eq(1)
    end

    it "stores discarded_reason when dropping" do
      feature = create(:feature, team: team, status: "idea")

      call(described_class, { "key" => feature.key, "status" => "discarded", "discarded_reason" => "duplicated" })

      expect(feature.reload.discarded_reason).to eq("duplicated")
    end
  end

  describe Mcp::Tools::AssignFeature do
    it "resolves \"me\" and adds the assignee" do
      feature = create(:feature, team: team)

      call(described_class, { "key" => feature.key, "add" => [ "me" ] })

      expect(feature.reload.assignee_ids.map(&:to_s)).to eq([ membership.id.to_s ])
    end

    it "removes with remove" do
      feature = create(:feature, team: team, assignee_ids: [ membership.id ])

      call(described_class, { "key" => feature.key, "remove" => [ "me" ] })

      expect(feature.reload.assignee_ids).to be_empty
    end
  end

  describe Mcp::Tools::AddArgument do
    it "adds a pro with the member as the author" do
      feature = create(:feature, team: team)

      result = call(described_class, { "feature_key" => feature.key, "kind" => "pro", "text" => "Good idea" })

      expect(feature.reload.arguments.find(result[:id]).author_id).to eq(membership.user_id)
    end

    it "an integration cannot add arguments" do
      feature = create(:feature, team: team)

      expect { call(described_class, { "feature_key" => feature.key, "kind" => "pro", "text" => "x" }, membership_override: nil) }
        .to raise_error(Mcp::ToolError)
    end
  end

  describe Mcp::Tools::VoteArgument do
    it "votes and removes the vote" do
      feature = create(:feature, team: team)
      argument = feature.arguments.create!(kind: "pro", text: "x", author_id: membership.user_id)

      up = call(described_class, { "feature_key" => feature.key, "argument_id" => argument.id.to_s, "vote" => true })
      expect(up[:votes]).to eq(1)

      down = call(described_class, { "feature_key" => feature.key, "argument_id" => argument.id.to_s, "vote" => false })
      expect(down[:votes]).to eq(0)
    end
  end

  describe Mcp::Tools::CreateObjective do
    it "creates the objective" do
      result = call(described_class, { "title" => "Win", "priority" => "must" })
      expect(Objective.where(id: result[:id]).first).to be_present
    end
  end

  describe Mcp::Tools::UpdateObjective do
    it "edits without deleting" do
      objective = create(:objective, team: team, title: "Old")

      result = call(described_class, { "key" => objective.key, "title" => "New" })

      expect(result[:title]).to eq("New")
    end
  end

  describe Mcp::Tools::CreateMilestone do
    it "creates the milestone" do
      result = call(described_class, { "title" => "Demo", "kind" => "demo", "due_at" => 2.days.from_now.iso8601 })
      expect(Milestone.where(id: result[:id]).first).to be_present
    end
  end

  describe Mcp::Tools::UpdateMilestone do
    it "edits the milestone" do
      milestone = create(:milestone, team: team, title: "Old")

      result = call(described_class, { "id" => milestone.id.to_s, "title" => "New" })

      expect(result[:title]).to eq("New")
    end
  end

  describe Mcp::Tools::SetAttribution do
    it "confirms the suggested attribution" do
      feature = create(:feature, team: team)
      event = create(:activity_event, :claude_turn, team: team, dedupe_key: "e1")
      event.build_attribution(feature_id: feature.id, method: "ai", status: "suggested", confidence: 0.6)
      event.save!

      call(described_class, { "event_id" => event.id.to_s, "action" => "confirm" })

      expect(event.reload.attribution.status).to eq("confirmed")
    end

    it "an invalid action returns a ToolError, not an uncaught exception" do
      event = create(:activity_event, :claude_turn, team: team, dedupe_key: "e1")

      expect { call(described_class, { "event_id" => event.id.to_s, "action" => "confirm" }) }.to raise_error(Mcp::ToolError)
    end
  end

  describe Mcp::Tools::RunAnalysis do
    it "queues an analysis" do
      membership.user.update!(gemini_api_key: "test-key")

      result = call(described_class)

      expect(AiAnalysis.where(id: result[:id]).first).to be_present
    end

    it "returns a ToolError when going over the manual quota" do
      membership.user.update!(gemini_api_key: "test-key")
      allow(Analysis::Quota).to receive(:check_manual!).and_raise(Analysis::Quota::ExceededError.new(3600))

      expect { call(described_class) }.to raise_error(Mcp::ToolError, /quota/)
    end

    it "returns a ToolError if I have no Gemini key set up" do
      expect { call(described_class) }.to raise_error(Mcp::ToolError, /Gemini key/)
    end
  end
end
