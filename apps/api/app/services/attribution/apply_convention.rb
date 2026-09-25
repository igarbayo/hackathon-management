# Layer 1 (RF-ATR-001): an explicit F-n in the event's title/summary or in the
# branch. Returns the mentioned keys and, if any is valid (it exists in the team
# and is not discarded), the feature to attribute to.
module Attribution
  class ApplyConvention
    # 05-atribucion.md#capa-1 gives this regex with `(?![0-9])` at the end, but
    # that version DOES match "F-123a" (it extracts 123), which contradicts the
    # spec's own text ("It does not accept... F-123a"). The lookahead is widened
    # to `(?![0-9A-Za-z])` so it also rejects attached letters, which is what
    # the spec says in prose. See specs/CHANGELOG.md.
    KEY_PATTERN = /(?<![A-Za-z0-9])[Ff]-(\d{1,5})(?![0-9A-Za-z])/

    Result = Struct.new(:feature, :mentioned_keys, keyword_init: true)

    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      searched_texts = [ event.title, event.summary, event.branch ].compact
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
