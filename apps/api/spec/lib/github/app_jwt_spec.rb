require "rails_helper"

RSpec.describe Github::AppJwt do
  around do |example|
    original_id = ENV["GITHUB_APP_ID"]
    original_key = ENV["GITHUB_APP_PRIVATE_KEY"]
    ENV["GITHUB_APP_ID"] = "12345"
    ENV["GITHUB_APP_PRIVATE_KEY"] = OpenSSL::PKey::RSA.generate(2048).to_pem
    example.run
    ENV["GITHUB_APP_ID"] = original_id
    ENV["GITHUB_APP_PRIVATE_KEY"] = original_key
  end

  it "genera un JWT RS256 con iss, iat y exp <= 10 minutos" do
    token = described_class.generate
    payload, header = JWT.decode(token, described_class.private_key.public_key, true, algorithms: [ "RS256" ])

    expect(header["alg"]).to eq("RS256")
    expect(payload["iss"]).to eq("12345")
    expect(payload["exp"] - payload["iat"]).to be <= 600
  end
end
