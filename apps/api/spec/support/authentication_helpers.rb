module AuthenticationHelpers
  def sign_in_as(user)
    raw_token = SecureRandom.hex(32)
    Session.create!(
      user: user,
      token_digest: Digest::SHA256.hexdigest(raw_token),
      expires_at: 30.days.from_now
    )
    cookies[:hb_session] = raw_token
  end

  def csrf_token
    get "/api/v1/csrf"
    json_response["csrf_token"]
  end

  def csrf_headers
    { "X-CSRF-Token" => csrf_token }
  end

  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
