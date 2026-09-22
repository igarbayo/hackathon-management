require "rails_helper"

RSpec.describe Repository, type: :model do
  it "un repositorio activo pertenece a un solo equipo (ADR-0007)" do
    create(:repository, github_repo_id: 555, active: true)
    other_team_same_repo = build(:repository, github_repo_id: 555, active: true)

    expect(other_team_same_repo).not_to be_valid
    expect(other_team_same_repo.errors[:base]).to be_present
  end

  it "permite el mismo github_repo_id si el primero está inactivo" do
    create(:repository, github_repo_id: 777, active: false)
    other_team_same_repo = build(:repository, github_repo_id: 777, active: true)

    expect(other_team_same_repo).to be_valid
  end
end
