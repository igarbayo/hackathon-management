# "Learning" (05-atribucion.md#capa-2): when a human confirms or assigns by hand
# an event whose branch is not the default one, that branch is added to the
# feature's branch_names, so the next events on that branch fall into layer 2
# with no human help.
module Attribution
  class LearnBranch
    def self.call(feature:, event:)
      return if event.branch.blank?
      return if feature.branch_names.include?(event.branch)

      repository = event.repository
      return if repository.present? && repository.default_branch == event.branch

      feature.add_to_set(branch_names: event.branch)
    end
  end
end
