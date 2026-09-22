module FeatureLookup
  def find_feature_by_key_or_id(key)
    feature = if key.to_s.match?(/\AF-\d+\z/i)
      Feature.where(team_id: current_team.id, number: key.to_s.sub(/\AF-/i, "").to_i).first
    else
      Feature.where(team_id: current_team.id, id: key).first
    end

    raise ApiError::NotFound.new(message: "feature no encontrada") unless feature

    feature
  end
end
