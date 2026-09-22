require "rails_helper"

RSpec.describe "Herramientas MCP de escritura" do
  let(:membership) { create(:membership) }
  let(:team) { membership.team }
  let(:resolved_token) { Tokens::Resolve.call(Pat::Create.call(membership: membership, name: "t", preset: "completo").raw_token) }

  def call(tool, args = {}, membership_override: membership, resolved_token_override: resolved_token)
    tool.call(team: team, membership: membership_override, resolved_token: resolved_token_override, args: args)
  end

  describe Mcp::Tools::ReportProgress do
    it "crea un ActivityEvent mcp/progress_report con atribución confirmada" do
      feature = create(:feature, team: team)

      result = call(described_class, { "feature_key" => feature.key, "summary" => "Hecho el login" })

      event = ActivityEvent.where(id: result[:event_id]).first
      expect(event.source).to eq("mcp")
      expect(event.attribution.status).to eq("confirmed")
      expect(event.attribution.feature_id).to eq(feature.id)
    end

    it "no cambia el estado de la feature (status_hint es solo informativo)" do
      feature = create(:feature, team: team, status: "idea")

      call(described_class, { "feature_key" => feature.key, "summary" => "x", "status_hint" => "started" })

      expect(feature.reload.status).to eq("idea")
    end

    it "límite de 30 al día por miembro y feature" do
      feature = create(:feature, team: team)
      30.times { call(described_class, { "feature_key" => feature.key, "summary" => "x" }) }

      expect { call(described_class, { "feature_key" => feature.key, "summary" => "x" }) }.to raise_error(Mcp::ToolError, /Límite diario/)
    end

    it "exige una persona, no una integración" do
      expect { call(described_class, { "feature_key" => create(:feature, team: team).key, "summary" => "x" }, membership_override: nil) }
        .to raise_error(Mcp::ToolError, /token de miembro o PAT/)
    end
  end

  describe Mcp::Tools::CreateFeature do
    it "crea la feature en idea y deja constancia con via mcp" do
      result = call(described_class, { "title" => "Nueva" })

      feature = Feature.where(id: result[:id]).first
      expect(feature.status).to eq("idea")
      event = ActivityEvent.where(kind: "api_change").first
      expect(event.via["channel"]).to eq("mcp")
    end

    it "assign_to_me asigna al miembro que llama" do
      result = call(described_class, { "title" => "Nueva", "assign_to_me" => true })

      expect(Feature.where(id: result[:id]).first.assignee_ids.map(&:to_s)).to eq([membership.id.to_s])
    end

    it "idempotency_key: la segunda llamada devuelve el mismo resultado sin crear otra feature" do
      call(described_class, { "title" => "Nueva", "idempotency_key" => "abc" })
      call(described_class, { "title" => "Otra", "idempotency_key" => "abc" })

      expect(Feature.where(team_id: team.id).count).to eq(1)
    end

    it "objective_keys inválido da un ToolError accionable" do
      expect { call(described_class, { "title" => "x", "objective_keys" => ["O-999"] }) }.to raise_error(Mcp::ToolError, /O-999/)
    end
  end

  describe Mcp::Tools::UpdateFeature do
    it "actualiza y devuelve la feature" do
      feature = create(:feature, team: team, title: "Vieja")

      result = call(described_class, { "key" => feature.key, "title" => "Nueva" })

      expect(result[:title]).to eq("Nueva")
    end

    it "expected_updated_at desajustado da conflicto con el documento actual" do
      feature = create(:feature, team: team)

      expect { call(described_class, { "key" => feature.key, "title" => "x", "expected_updated_at" => 1.day.ago.iso8601 }) }
        .to raise_error(Mcp::ToolError, /Conflicto/)
    end
  end

  describe Mcp::Tools::MoveFeature do
    it "cambia el estado y dispara el evento" do
      feature = create(:feature, team: team, status: "idea")

      call(described_class, { "key" => feature.key, "status" => "in_progress" })

      expect(feature.reload.status).to eq("in_progress")
      expect(ActivityEvent.where(kind: "feature_status_changed").count).to eq(1)
    end

    it "guarda discarded_reason al descartar" do
      feature = create(:feature, team: team, status: "idea")

      call(described_class, { "key" => feature.key, "status" => "discarded", "discarded_reason" => "duplicada" })

      expect(feature.reload.discarded_reason).to eq("duplicada")
    end
  end

  describe Mcp::Tools::AssignFeature do
    it "resuelve \"me\" y añade el assignee" do
      feature = create(:feature, team: team)

      call(described_class, { "key" => feature.key, "add" => ["me"] })

      expect(feature.reload.assignee_ids.map(&:to_s)).to eq([membership.id.to_s])
    end

    it "quita con remove" do
      feature = create(:feature, team: team, assignee_ids: [membership.id])

      call(described_class, { "key" => feature.key, "remove" => ["me"] })

      expect(feature.reload.assignee_ids).to be_empty
    end
  end

  describe Mcp::Tools::AddArgument do
    it "añade un pro con el miembro como autor" do
      feature = create(:feature, team: team)

      result = call(described_class, { "feature_key" => feature.key, "kind" => "pro", "text" => "Buena idea" })

      expect(feature.reload.arguments.find(result[:id]).author_id).to eq(membership.user_id)
    end

    it "una integración no puede añadir argumentos" do
      feature = create(:feature, team: team)

      expect { call(described_class, { "feature_key" => feature.key, "kind" => "pro", "text" => "x" }, membership_override: nil) }
        .to raise_error(Mcp::ToolError)
    end
  end

  describe Mcp::Tools::VoteArgument do
    it "vota y quita el voto" do
      feature = create(:feature, team: team)
      argument = feature.arguments.create!(kind: "pro", text: "x", author_id: membership.user_id)

      up = call(described_class, { "feature_key" => feature.key, "argument_id" => argument.id.to_s, "vote" => true })
      expect(up[:votes]).to eq(1)

      down = call(described_class, { "feature_key" => feature.key, "argument_id" => argument.id.to_s, "vote" => false })
      expect(down[:votes]).to eq(0)
    end
  end

  describe Mcp::Tools::CreateObjective do
    it "crea el objetivo" do
      result = call(described_class, { "title" => "Ganar", "priority" => "must" })
      expect(Objective.where(id: result[:id]).first).to be_present
    end
  end

  describe Mcp::Tools::UpdateObjective do
    it "edita sin borrar" do
      objective = create(:objective, team: team, title: "Vieja")

      result = call(described_class, { "key" => objective.key, "title" => "Nueva" })

      expect(result[:title]).to eq("Nueva")
    end
  end

  describe Mcp::Tools::CreateMilestone do
    it "crea el milestone" do
      result = call(described_class, { "title" => "Demo", "kind" => "demo", "due_at" => 2.days.from_now.iso8601 })
      expect(Milestone.where(id: result[:id]).first).to be_present
    end
  end

  describe Mcp::Tools::UpdateMilestone do
    it "edita el milestone" do
      milestone = create(:milestone, team: team, title: "Vieja")

      result = call(described_class, { "id" => milestone.id.to_s, "title" => "Nueva" })

      expect(result[:title]).to eq("Nueva")
    end
  end

  describe Mcp::Tools::SetAttribution do
    it "confirma la atribución sugerida" do
      feature = create(:feature, team: team)
      event = create(:activity_event, :claude_turn, team: team, dedupe_key: "e1")
      event.build_attribution(feature_id: feature.id, method: "ai", status: "suggested", confidence: 0.6)
      event.save!

      call(described_class, { "event_id" => event.id.to_s, "action" => "confirm" })

      expect(event.reload.attribution.status).to eq("confirmed")
    end

    it "una acción inválida da un ToolError, no una excepción sin capturar" do
      event = create(:activity_event, :claude_turn, team: team, dedupe_key: "e1")

      expect { call(described_class, { "event_id" => event.id.to_s, "action" => "confirm" }) }.to raise_error(Mcp::ToolError)
    end
  end

  describe Mcp::Tools::RunAnalysis do
    it "encola un análisis" do
      result = call(described_class)
      expect(AiAnalysis.where(id: result[:id]).first).to be_present
    end

    it "da un ToolError al superar la cuota manual" do
      allow(Analysis::Quota).to receive(:check_manual!).and_raise(Analysis::Quota::ExceededError.new(3600))

      expect { call(described_class) }.to raise_error(Mcp::ToolError, /cuota/)
    end
  end
end
