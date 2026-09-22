# RF-FEAT/RF-OBJ: If-Match: <updated_at> evita que dos personas arrastrando
# tarjetas a la vez se pisen. Si no coincide, 409 con el documento actual.
module OptimisticConcurrency
  def check_if_match!(record, serializer)
    if_match = request.headers["If-Match"]
    return if if_match.blank?
    return if if_match == record.updated_at.iso8601(3)

    raise ApiError::Conflict.new(message: "el documento cambió mientras tanto", details: serializer.call(record).as_json)
  end
end
