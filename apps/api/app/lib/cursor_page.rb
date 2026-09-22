# Paginación por cursor descendente por (occurred_at, _id), tal como pide
# 03-api.md#convenciones-generales: { data: [...], next_cursor: "…" | null }.
module CursorPage
  module_function

  def encode(occurred_at, id)
    Base64.urlsafe_encode64("#{occurred_at.utc.iso8601(6)}|#{id}")
  end

  def decode(cursor)
    return nil if cursor.blank?

    decoded = Base64.urlsafe_decode64(cursor)
    occurred_at, id = decoded.split("|", 2)
    [ Time.iso8601(occurred_at), id ]
  rescue ArgumentError
    nil
  end

  def apply(scope, cursor:, limit:)
    if (decoded = decode(cursor))
      occurred_at, id = decoded
      scope = scope.any_of(
        { :occurred_at.lt => occurred_at },
        { occurred_at: occurred_at, :id.lt => BSON::ObjectId.from_string(id) }
      )
    end

    records = scope.order(occurred_at: :desc, _id: :desc).limit(limit + 1).to_a
    has_more = records.size > limit
    records = records.first(limit)
    next_cursor = has_more && records.last ? encode(records.last.occurred_at, records.last.id) : nil

    [ records, next_cursor ]
  end
end
