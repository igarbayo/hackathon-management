# GET /api/v1/openapi.json (RF-API-007). Public, no auth.
module Api
  module V1
    class OpenapiController < ApplicationController
      def show
        render json: ::Api::OpenapiDocument.generate
      end
    end
  end
end
