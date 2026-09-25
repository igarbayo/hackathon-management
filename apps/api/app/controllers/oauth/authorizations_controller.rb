# GET /oauth/authorize and POST /oauth/authorize/decision (RF-API-012).
module OAuth
  class AuthorizationsController < ApplicationController
    before_action :authenticate_user!, only: %i[decision consent_info]
    before_action :verify_csrf!, only: :decision

    # Validates the request and redirects to the web app's consent screen. If
    # there is no session, it goes through login first (the same `next` the CLI
    # device flow uses).
    def new
      validated = ::OAuth::ValidateAuthorizeParams.call(params)

      request_id = ::OAuth::AuthorizeRequest.generate(
        "client_id" => validated.client.client_id,
        "redirect_uri" => validated.redirect_uri,
        "scope" => params[:scope].to_s,
        "state" => params[:state].to_s,
        "code_challenge" => params[:code_challenge],
        "resource" => params[:resource]
      )

      consent_path = "/oauth/consent?request_id=#{CGI.escape(request_id)}"
      redirect_to(current_user ? "#{app_url}#{consent_path}" : "#{app_url}/login?next=#{CGI.escape(consent_path)}", allow_other_host: true)
    rescue ::OAuth::ValidateAuthorizeParams::DirectError => e
      render json: { error: "invalid_request", error_description: e.message }, status: :bad_request
    rescue ::OAuth::ValidateAuthorizeParams::RedirectError => e
      redirect_to(oauth_error_redirect(params[:redirect_uri], e.code, params[:state]), allow_other_host: true)
    end

    # The web app (with a session and CSRF) sends the person's decision. It
    # returns the destination as JSON instead of a 302: the SPA calls it with
    # fetch, and a cross-origin redirect cannot be followed there without the
    # third party's CORS. The web app itself does window.location =
    # redirect_url.
    def decision
      recovered = ::OAuth::AuthorizeRequest.verify(params[:request_id])

      unless ActiveModel::Type::Boolean.new.cast(params[:approve])
        return render json: { redirect_url: oauth_error_redirect(recovered["redirect_uri"], "access_denied", recovered["state"]) }
      end

      membership = Membership.where(team_id: params[:team_id], user_id: current_user.id).first
      raise ApiError::NotFound.new(message: "team not found") unless membership

      requested_scopes = recovered["scope"].to_s.split
      granted_scopes = Array(params[:scopes]).presence || requested_scopes.presence || [ "read" ]
      unless requested_scopes.blank? || (granted_scopes - requested_scopes).empty?
        return render json: { redirect_url: oauth_error_redirect(recovered["redirect_uri"], "invalid_scope", recovered["state"]) }
      end

      client = OAuthClient.where(client_id: recovered["client_id"]).first
      raise ApiError::NotFound.new(message: "client not found") unless client

      code = ::OAuth::AuthorizeCode.call(
        client: client, user: current_user, membership: membership, scopes: granted_scopes | [ "read" ],
        redirect_uri: recovered["redirect_uri"], resource: recovered["resource"], code_challenge: recovered["code_challenge"]
      )

      redirect_uri = URI.parse(recovered["redirect_uri"])
      query = URI.decode_www_form(redirect_uri.query.to_s) << [ "code", code ] << [ "state", recovered["state"] ]
      redirect_uri.query = URI.encode_www_form(query)
      render json: { redirect_url: redirect_uri.to_s }
    end

    # GET /oauth/consent_info?request_id=… (session): what the consent screen
    # needs to show, without the web app having to decode the signed request_id
    # itself.
    def consent_info
      recovered = ::OAuth::AuthorizeRequest.verify(params[:request_id])
      client = OAuthClient.where(client_id: recovered["client_id"]).first
      raise ApiError::NotFound.new(message: "client not found") unless client

      render json: {
        client: { name: client.name, client_uri: client.client_uri, logo_uri: client.logo_uri, first_party: client.first_party? },
        redirect_uri: recovered["redirect_uri"],
        scopes: recovered["scope"].to_s.split
      }
    end

    private

    def oauth_error_redirect(redirect_uri, error_code, state)
      uri = URI.parse(redirect_uri)
      query = URI.decode_www_form(uri.query.to_s) << [ "error", error_code ] << [ "state", state.to_s ]
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end

    def app_url
      ENV.fetch("APP_URL", "http://localhost:3000")
    end
  end
end
