require "rails_helper"

RSpec.describe Attribution::Decide do
  let(:membership) { create(:membership) }
  let(:team) { membership.team }
  let(:feature) { create(:feature, team: team) }

  def suggested_event(branch: nil)
    event = create(:activity_event, :github_commit, team: team, branch: branch)
    event.build_attribution(feature_id: feature.id, method: "ai", status: "suggested", confidence: 0.7)
    event.save!
    event
  end

  describe "confirm" do
    it "pasa a confirmed y registra quién decidió" do
      event = suggested_event
      described_class.call(event: event, action: "confirm", decided_by: membership.user)

      expect(event.attribution.status).to eq("confirmed")
      expect(event.attribution.method).to eq("ai")
      expect(event.attribution.decided_by_id).to eq(membership.user.id)
    end

    it "aprende la rama si no es la por defecto" do
      event = suggested_event(branch: "f-99-custom")
      described_class.call(event: event, action: "confirm", decided_by: membership.user)

      expect(feature.reload.branch_names).to include("f-99-custom")
    end
  end

  describe "reject" do
    it "pasa a rejected, quita el feature_id y lo guarda en rejected_feature_ids" do
      event = suggested_event
      described_class.call(event: event, action: "reject", decided_by: membership.user)

      expect(event.attribution.status).to eq("rejected")
      expect(event.attribution.feature_id).to be_nil
      expect(event.attribution.rejected_feature_ids).to include(feature.id)
    end
  end

  describe "set" do
    it "asigna a mano con method manual" do
      event = create(:activity_event, :github_commit, team: team)
      described_class.call(event: event, action: "set", decided_by: membership.user, feature: feature)

      expect(event.attribution.method).to eq("manual")
      expect(event.attribution.status).to eq("confirmed")
      expect(event.attribution.feature_id).to eq(feature.id)
    end

    it "conserva rejected_feature_ids previos al corregir una atribución" do
      event = suggested_event
      described_class.call(event: event, action: "reject", decided_by: membership.user)

      other_feature = create(:feature, team: team)
      described_class.call(event: event, action: "set", decided_by: membership.user, feature: other_feature)

      expect(event.attribution.feature_id).to eq(other_feature.id)
      expect(event.attribution.rejected_feature_ids).to include(feature.id)
    end
  end

  describe "unlink" do
    it "deja el evento sin atribuir y recuerda la feature para no volver a sugerirla" do
      event = suggested_event
      described_class.call(event: event, action: "confirm", decided_by: membership.user)

      described_class.call(event: event, action: "unlink", decided_by: membership.user)

      expect(event.attribution.feature_id).to be_nil
      expect(event.attribution.status).to eq("rejected")
      expect(event.attribution.rejected_feature_ids).to include(feature.id)
    end
  end

  it "confirm sin sugerencia previa es un error" do
    event = create(:activity_event, :github_commit, team: team)

    expect { described_class.call(event: event, action: "confirm", decided_by: membership.user) }
      .to raise_error(Attribution::Decide::InvalidAction)
  end
end
