module Api
  module V1
    class CsrfController < ApplicationController
      def show
        seed = cookies[Csrf::SEED_COOKIE] || Csrf.generate_seed

        cookies[Csrf::SEED_COOKIE] = {
          value: seed,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax
        }

        render json: { csrf_token: Csrf.token_for(seed) }
      end
    end
  end
end
