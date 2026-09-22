require "rails_helper"

RSpec.describe Milestone, type: :model do
  it "no limpia due_soon_notified_at al crearse con uno ya puesto" do
    milestone = create(:milestone, due_soon_notified_at: 5.minutes.ago)

    expect(milestone.due_soon_notified_at).to be_present
  end

  it "limpia due_soon_notified_at cuando cambia due_at" do
    milestone = create(:milestone, due_soon_notified_at: 5.minutes.ago)

    milestone.update!(due_at: 3.days.from_now)

    expect(milestone.due_soon_notified_at).to be_nil
  end

  it "no toca due_soon_notified_at si se edita otro campo" do
    milestone = create(:milestone, due_soon_notified_at: 5.minutes.ago)

    milestone.update!(title: "Nuevo título")

    expect(milestone.due_soon_notified_at).to be_present
  end
end
