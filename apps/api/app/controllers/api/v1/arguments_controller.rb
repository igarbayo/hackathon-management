module Api
  module V1
    class ArgumentsController < Api::V1::BaseController
      include TeamScoping
      include FeatureLookup

      def create
        feature = find_feature
        argument = feature.arguments.create!(
          kind: params[:kind],
          text: params[:text],
          author_id: current_user.id
        )

        render json: argument_json(argument), status: :created
      end

      def update
        argument = find_argument
        raise ApiError::Forbidden.new(message: "solo el autor puede editarlo") unless argument.author_id == current_user.id

        argument.update!(text: params[:text])
        render json: argument_json(argument)
      end

      def destroy
        argument = find_argument
        is_author = argument.author_id == current_user.id
        raise ApiError::Forbidden.new unless is_author || current_membership.owner?

        argument.destroy!
        head :no_content
      end

      def vote
        argument = find_argument

        if request.request_method == "PUT"
          argument.add_to_set(voter_ids: current_user.id)
        else
          argument.pull(voter_ids: current_user.id)
        end

        render json: argument_json(argument.reload)
      end

      private

      def find_feature
        find_feature_by_key_or_id(params[:feature_key])
      end

      def find_argument
        feature = find_feature
        argument = feature.arguments.find(params[:id])
        raise ApiError::NotFound.new(message: "argumento no encontrado") unless argument

        argument
      end

      def argument_json(argument)
        {
          id: argument.id.to_s,
          kind: argument.kind,
          text: argument.text,
          author_id: argument.author_id&.to_s,
          votes: argument.votes,
          voted_by_me: argument.voter_ids.include?(current_user.id)
        }
      end
    end
  end
end
