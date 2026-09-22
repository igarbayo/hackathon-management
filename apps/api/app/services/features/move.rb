# RF-FEAT-005: mueve la tarjeta en el kanban calculando `position` como un
# float entre sus vecinos, para no tener que reindexar el resto de la columna.
module Features
  class Move
    def self.call(feature:, status:, before_id: nil, after_id: nil)
      siblings = Feature.where(team_id: feature.team_id, status: status).and(:id.ne => feature.id)
                         .order(position: :asc).to_a

      new_position = compute_position(siblings, before_id, after_id)

      status_changed = feature.status != status
      feature.status = status
      feature.position = new_position
      feature.save!

      if status_changed
        ActivityEvent.create!(
          team_id: feature.team_id,
          source: "system",
          kind: "feature_status_changed",
          dedupe_key: "system:feature_status_changed:#{feature.id}:#{feature.updated_at.to_f}",
          occurred_at: Time.current,
          title: "#{feature.key} pasó a #{status}",
          payload: { entity: "feature", key: feature.key, action: "status_changed", fields: ["status"] }
        )
      end

      feature
    end

    def self.compute_position(siblings, before_id, after_id)
      before_feature = before_id.present? ? siblings.find { |f| f.id.to_s == before_id.to_s } : nil
      after_feature = after_id.present? ? siblings.find { |f| f.id.to_s == after_id.to_s } : nil

      if after_feature && before_feature
        (after_feature.position + before_feature.position) / 2.0
      elsif after_feature
        following = siblings.find { |f| f.position > after_feature.position }
        following ? (after_feature.position + following.position) / 2.0 : after_feature.position + 1.0
      elsif before_feature
        preceding = siblings.select { |f| f.position < before_feature.position }.max_by(&:position)
        preceding ? (before_feature.position + preceding.position) / 2.0 : before_feature.position - 1.0
      else
        max = siblings.map(&:position).max
        max ? max + 1.0 : 0.0
      end
    end
  end
end
