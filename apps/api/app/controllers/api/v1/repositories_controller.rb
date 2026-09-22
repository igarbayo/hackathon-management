module Api
  module V1
    class RepositoriesController < Api::V1::BaseController
      include TeamScoping

      # No está en 03-api.md, pero RF-GH-010 ("repos vinculados") lo necesita
      # y es el complemento natural de create/destroy.
      def index
        repositories = Repository.where(team_id: current_team.id, active: true)
        render json: { data: repositories.map { |r| RepositorySerializer.new(r).as_json } }
      end

      def create
        full_name = params[:full_name].presence || Github::RepoUrl.parse(params[:url])
        raise ApiError::BadRequest.new(message: "full_name o url no válidos") unless full_name

        if already_linked_elsewhere?(full_name)
          raise ApiError::Conflict.new(
            message: "este repositorio ya está vinculado a otro equipo",
            details: { code: "repo_already_linked" }
          )
        end

        result = Github::LinkRepository.call(team: current_team, user: current_user, full_name: full_name)

        if result.linked
          Github::ImportHistoryJob.perform_async(result.repository.id.to_s)
          render json: RepositorySerializer.new(result.repository).as_json, status: :created
        else
          render json: { needs_install: true, install_url: result.install_url }
        end
      end

      # RNF-GH-003: "Resincronizar" relanza la importación del histórico.
      def resync
        repository = Repository.where(team_id: current_team.id, id: params[:id]).first
        raise ApiError::NotFound.new(message: "repositorio no encontrado") unless repository

        Github::ImportHistoryJob.perform_async(repository.id.to_s)
        head :accepted
      end

      def destroy
        repository = Repository.where(team_id: current_team.id, id: params[:id]).first
        raise ApiError::NotFound.new(message: "repositorio no encontrado") unless repository

        repository.update!(active: false)
        head :no_content
      end

      private

      def already_linked_elsewhere?(full_name)
        Repository.where(full_name: full_name, active: true).where(:team_id.ne => current_team.id).exists?
      end
    end
  end
end
