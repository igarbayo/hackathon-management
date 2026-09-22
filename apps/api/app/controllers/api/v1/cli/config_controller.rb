# GET /cli/config (RF-CC-… flujo de init, paso 4). Bearer hb_mt_.
module Api
  module V1
    module Cli
      class ConfigController < ApplicationController
        include TokenAuthentication
        before_action :authenticate_member_token!

        DEFAULT_EXCLUDE_GLOBS = [".env*", "**/secrets/**", "**/*.pem", "**/*.key", "**/credentials*"].freeze

        def show
          repos = Repository.where(team_id: current_team.id, active: true).pluck(:remote_urls).flatten
          render json: { repos: repos, exclude_globs: DEFAULT_EXCLUDE_GLOBS }
        end
      end
    end
  end
end
