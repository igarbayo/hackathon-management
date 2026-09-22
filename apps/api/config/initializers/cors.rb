# La web y la api están en el mismo "site" (mismo dominio, distinto puerto/subdominio)
# para que la cookie de sesión SameSite=Lax funcione (ADR-0008). CORS solo necesita
# permitir ese origen concreto con credenciales.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("APP_URL", "http://localhost:3000")

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: true
  end
end
