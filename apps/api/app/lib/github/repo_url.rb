# Normalizes what the user pastes ("https://github.com/org/repo", "org/repo",
# with or without ".git") to "org/repo" (RF-GH-020).
module Github
  module RepoUrl
    PATTERN = %r{\A(?:https?://github\.com/)?(?<full_name>[\w.-]+/[\w.-]+?)(?:\.git)?/?\z}

    def self.parse(input)
      match = input.to_s.strip.match(PATTERN)
      match && match[:full_name]
    end
  end
end
