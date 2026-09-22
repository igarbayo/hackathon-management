# GET /api/v1/openapi.json (RF-API-007). Se genera a partir de las rutas
# reales y de las declaraciones session_only/requires_scope de TeamScoping
# (12-acceso-programatico.md#openapi--rf-api-007-f2-aceptado), en vez de
# mantenerse a mano: no puede quedar desincronizado de lo que de verdad
# exige cada endpoint, porque lee la misma fuente que los aplica en
# tiempo de petición.
#
# Los pocos endpoints que no usan TeamScoping (login, device flow, MCP…)
# no declaran scope por acción, así que su acceso se documenta a mano en
# MANUAL_ACCESS: son rutas estables que cambian poco.
module Api
  class OpenapiDocument
    EXCLUDED_PREFIXES = %w[api/v1/auth/github api/v1/auth/google].freeze

    MANUAL_ACCESS = {
      "api/v1/csrf#show" => "public",
      "api/v1/auth/registrations#create" => "public",
      "api/v1/auth/sessions#create" => "public",
      "api/v1/auth/sessions#destroy" => "session_only",
      "api/v1/auth/github#new" => "public",
      "api/v1/auth/github#callback" => "public",
      "api/v1/auth/google#new" => "public",
      "api/v1/auth/google#callback" => "public",
      "api/v1/token_introspection#show" => "bearer",
      "api/v1/me#show" => "bearer_or_session",
      "api/v1/me#update" => "session_only",
      "api/v1/me#destroy" => "session_only",
      "api/v1/me#destroy_identity" => "session_only",
      "api/v1/github_setup#show" => "public",
      "api/v1/cli/device#create" => "public",
      "api/v1/cli/device#token" => "public",
      "api/v1/cli/config#show" => "bearer",
      "api/v1/cli/me#update" => "bearer",
      "api/v1/cli/me#destroy" => "bearer",
      "api/v1/ingest/claude_code#create" => "bearer:ingest",
      "api/v1/mcp#create" => "bearer"
    }.freeze

    def self.generate
      new.generate
    end

    def generate
      {
        "openapi" => "3.1.0",
        "info" => { "title" => "Hackboard API", "version" => "1.0.0", "description" => "Ver specs/03-api.md y specs/12-acceso-programatico.md." },
        "servers" => [ { "url" => "#{ENV.fetch('API_URL', '')}/api/v1" } ],
        "paths" => build_paths
      }
    end

    private

    def build_paths
      paths = {}

      relevant_routes.each do |route|
        controller_name = route.defaults[:controller]
        action = route.defaults[:action]
        controller = controller_class(controller_name)
        next unless controller

        path = openapi_path(route.path.spec.to_s, controller_name)
        (paths[path] ||= {})[route.verb.downcase] = operation_for(controller_name, action, controller)
      end

      paths
    end

    def relevant_routes
      Rails.application.routes.routes.select do |route|
        controller = route.defaults[:controller]
        controller&.start_with?("api/v1") && EXCLUDED_PREFIXES.none? { |prefix| controller.start_with?(prefix) } && route.defaults[:action].present?
      end
    end

    def controller_class(controller_name)
      "#{controller_name}_controller".camelize.constantize
    rescue NameError
      nil
    end

    def openapi_path(spec, controller_name)
      spec
        .sub(%r{\(\.:format\)\z}, "")
        .sub(%r{\A/api/v1}, "")
        .gsub(/:(\w+)/, '{\1}')
        .then { |p| p.empty? ? "/#{controller_name}" : p }
    end

    def operation_for(controller_name, action, controller)
      key = "#{controller_name}##{action}"
      op = {
        "operationId" => key.tr("/", "_").tr("#", "_"),
        "responses" => { "200" => { "description" => "OK" }, "404" => { "description" => "No encontrado o equipo ajeno (RNF-SEC-001)" } }
      }

      if controller.respond_to?(:session_only_actions) && controller.session_only_actions.include?(action.to_sym)
        op["x-hackboard-access"] = "session_only"
      elsif controller.respond_to?(:scope_requirements)
        requirement = controller.scope_requirements.find { |r| r[:actions].include?(action.to_sym) }
        op["x-hackboard-scope"] = requirement ? requirement[:scope] : "read"
      else
        op["x-hackboard-access"] = MANUAL_ACCESS.fetch(key, "session_only")
      end

      op
    end
  end
end
