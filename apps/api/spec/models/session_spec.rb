require "rails_helper"

RSpec.describe Session, type: :model do
  it "is expired when expires_at has already passed" do
    session = create(:session, expires_at: 1.minute.ago)

    expect(session.expired?).to be true
  end

  it "renews the expiry when the activity is touched" do
    session = create(:session, expires_at: 1.day.from_now)

    session.touch_activity!

    expect(session.expires_at).to be_within(5.seconds).of(Session::SLIDING_TTL.from_now)
  end
end
