# input_hash = SHA-256 del contexto sin el campo `ahora`, redondeando las
# horas restantes a la hora (06-analisis-ia.md#construcción-del-contexto).
module Analysis
  class InputHash
    def self.call(context)
      hashable = deep_round(context.deep_dup)
      hashable["hackathon"]&.delete("now")

      Digest::SHA256.hexdigest(hashable.to_json)
    end

    def self.deep_round(node)
      case node
      when Hash
        node.each do |key, value|
          node[key] = key == "hours_remaining" && value.is_a?(Numeric) ? value.round : deep_round(value)
        end
      when Array
        node.map { |item| deep_round(item) }
      else
        node
      end
    end
  end
end
