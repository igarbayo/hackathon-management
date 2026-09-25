# The web app and the api are on the same "site" (same domain, different
# port/subdomain) so the SameSite=Lax session cookie works (ADR-0008). CORS only needs
# to allow that exact origin with credentials.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("APP_URL", "http://localhost:3000")

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: true
  end
end
