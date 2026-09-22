# GET /oauth/authorize y POST /oauth/authorize/decision (RF-API-012).
module OAuth
  class AuthorizationsController < ApplicationController
    before_action :authenticate_user!, only: %i[decision consent_info]
    before_action :verify_csrf!, only: :decision

    # Valida la petición y redirige a la pantalla de consentimiento de la
    # web. Si no hay sesión, pasa antes por el login (mismo `next` que usa
    # el device flow del CLI).
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

    # La web (con sesión y CSRF) envía la decisión de la persona. Devuelve
    # el destino en JSON en vez de un 302: lo llama fetch desde la SPA, y un
    # redirect cruzado de origen no se puede seguir ahí sin CORS del
    # tercero. La propia web hace window.location = redirect_url.
    def decision
      recovered = ::OAuth::AuthorizeRequest.verify(params[:request_id])

      unless ActiveModel::Type::Boolean.new.cast(params[:approve])
        return render json: { redirect_url: oauth_error_redirect(recovered["redirect_uri"], "access_denied", recovered["state"]) }
      end

      membership = Membership.where(team_id: params[:team_id], user_id: current_user.id).first
      raise ApiError::NotFound.new(message: "equipo no encontrado") unless membership

      requested_scopes = recovered["scope"].to_s.split
      granted_scopes = Array(params[:scopes]).presence || requested_scopes.presence || [ "read" ]
      unless requested_scopes.blank? || (granted_scopes - requested_scopes).empty?
        return render json: { redirect_url: oauth_error_redirect(recovered["redirect_uri"], "invalid_scope", recovered["state"]) }
      end

      client = OAuthClient.where(client_id: recovered["client_id"]).first
      raise ApiError::NotFound.new(message: "cliente no encontrado") unless client

      code = ::OAuth::AuthorizeCode.call(
        client: client, user: current_user, membership: membership, scopes: granted_scopes | [ "read" ],
        redirect_uri: recovered["redirect_uri"], resource: recovered["resource"], code_challenge: recovered["code_challenge"]
      )

      redirect_uri = URI.parse(recovered["redirect_uri"])
      query = URI.decode_www_form(redirect_uri.query.to_s) << [ "code", code ] << [ "state", recovered["state"] ]
      redirect_uri.query = URI.encode_www_form(query)
      render json: { redirect_url: redirect_uri.to_s }
    end

    # GET /oauth/consent_info?request_id=… (sesión): lo que la pantalla de
    # consentimiento necesita mostrar, sin que la web tenga que decodificar
    # el request_id firmado ella misma.
    def consent_info
      recovered = ::OAuth::AuthorizeRequest.verify(params[:request_id])
      client = OAuthClient.where(client_id: recovered["client_id"]).first
      raise ApiError::NotFound.new(message: "cliente no encontrado") unless client

      render json: {
        client: { name: client.name, client_uri: client.client_uri, logo_uri: client.logo_uri, first_party: client.first_party? },
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
