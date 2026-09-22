# "Aprendizaje" (05-atribucion.md#capa-2): cuando un humano confirma o asigna
# a mano un evento cuya rama no es la por defecto, esa rama se añade a
# branch_names de la feature, para que los siguientes eventos de esa rama
# caigan en la capa 2 sin intervención humana.
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
