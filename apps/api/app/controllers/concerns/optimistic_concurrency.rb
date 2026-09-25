# RF-FEAT/RF-OBJ: If-Match: <updated_at> keeps two people dragging cards at the
# same time from overwriting each other. If it does not match, 409 with the
# current document.
module OptimisticConcurrency
  def check_if_match!(record, serializer)
    if_match = request.headers["If-Match"]
    return if if_match.blank?
    return if if_match == record.updated_at.iso8601(3)

    raise ApiError::Conflict.new(message: "the document changed in the meantime", details: serializer.call(record).as_json)
  end
end
