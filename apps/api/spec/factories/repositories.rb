FactoryBot.define do
  factory :repository do
    team
    sequence(:github_repo_id) { |n| n }
    sequence(:full_name) { |n| "hackboard/repo-#{n}" }
    default_branch { "main" }
    remote_urls { ["github.com/hackboard/repo"] }
  end
end
