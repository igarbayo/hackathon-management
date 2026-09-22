require "rails_helper"

RSpec.describe Session, type: :model do
  it "está caducada cuando expires_at ya pasó" do
    session = create(:session, expires_at: 1.minute.ago)

    expect(session.expired?).to be true
  end

  it "renueva la caducidad al tocar la actividad" do
    session = create(:session, expires_at: 1.day.from_now)

    session.touch_activity!

    expect(session.expires_at).to be_within(5.seconds).of(Session::SLIDING_TTL.from_now)
  end
end
