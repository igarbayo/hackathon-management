class Session
  include Mongoid::Document
  include Mongoid::Timestamps

  SLIDING_TTL = 30.days

  field :user_id, type: BSON::ObjectId
  field :token_digest, type: String
  field :expires_at, type: Time
  field :user_agent, type: String
  field :ip, type: String

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  index({ token_digest: 1 }, { unique: true })
  index({ expires_at: 1 }, { expire_after_seconds: 0 })

  scope :active, -> { where(:expires_at.gt => Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def touch_activity!
    update!(expires_at: SLIDING_TTL.from_now)
  end
end
