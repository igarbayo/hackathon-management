# Capa 1 (RF-ATR-001): F-n explícita en el título/resumen del evento o en la
# rama. Devuelve las claves mencionadas y, si alguna es válida (existe en el
# equipo y no está discarded), la feature a la que atribuir.
module Attribution
  class ApplyConvention
    # 05-atribucion.md#capa-1 da esta regex con `(?![0-9])` al final, pero esa
    # variante SÍ matchea "F-123a" (extrae 123), contradiciendo el propio
    # texto de la spec ("No acepta... F-123a"). Se amplía el lookahead a
    # `(?![0-9A-Za-z])` para que rechace también letras pegadas, que es lo
    # que la spec dice en prosa. Ver specs/CHANGELOG.md.
    KEY_PATTERN = /(?<![A-Za-z0-9])[Ff]-(\d{1,5})(?![0-9A-Za-z])/

    Result = Struct.new(:feature, :mentioned_keys, keyword_init: true)

    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      searched_texts = [event.title, event.summary, event.branch].compact
      numbers = searched_texts.flat_map { |text| text.scan(KEY_PATTERN).flatten }.map(&:to_i).uniq
      mentioned_keys = numbers.map { |n| "F-#{n}" }

      feature = numbers.lazy.map { |n| find_feature(n) }.find(&:itself)

      Result.new(feature: feature, mentioned_keys: mentioned_keys)
    end

    private

    attr_reader :event

    def find_feature(number)
      Feature.where(team_id: event.team_id, number: number).where(:status.ne => "discarded").first
    end
  end
end
