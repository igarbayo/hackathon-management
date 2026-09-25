module Api
  module V1
    class RepositoriesController < Api::V1::BaseController
      include TeamScoping

      session_only :create, :destroy, :resync
      requires_scope "read", only: :index

      # Not in 03-api.md, but RF-GH-010 ("linked repos") needs it and it is the
      # natural complement of create/destroy.
      def index
        repositories = Repository.where(team_id: current_team.id, active: true)
        render json: { data: repositories.map { |r| RepositorySerializer.new(r).as_json } }
      end

      def create
        full_name = params[:full_name].presence || Github::RepoUrl.parse(params[:url])
        raise ApiError::BadRequest.new(message: "invalid full_name or url") unless full_name

        if already_linked_elsewhere?(full_name)
          raise ApiError::Conflict.new(
            message: "this repository is already linked to another team",
            details: { code: "repo_already_linked" }
          )
        end

        result = Github::LinkRepository.call(team: current_team, user: current_user, full_name: full_name,
                                              return_to: params[:return_to])

        if result.linked
          Github::ImportHistoryJob.enqueue(result.repository)
          render json: RepositorySerializer.new(result.repository).as_json, status: :created
        else
          render json: { needs_install: true, install_url: result.install_url }
        end
      end

      # RNF-GH-003: "Resync" runs the history import again.
      def resync
        repository = Repository.where(team_id: current_team.id, id: params[:id]).first
        raise ApiError::NotFound.new(message: "repository not found") unless repository

        Github::ImportHistoryJob.enqueue(repository)
        head :accepted
      end

      def destroy
        repository = Repository.where(team_id: current_team.id, id: params[:id]).first
        raise ApiError::NotFound.new(message: "repository not found") unless repository

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
