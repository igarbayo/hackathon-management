require "rails_helper"

RSpec.describe CloudflareRemoteIp do
  let(:inner) { ->(env) { [ 200, {}, [ ActionDispatch::Request.new(env).remote_ip ] ] } }
  let(:app) { described_class.new(ActionDispatch::RemoteIp.new(inner)) }

  def remote_ip(env)
    app.call(Rack::MockRequest.env_for("/", env)).last.first
  end

  it "usa CF-Connecting-IP cuando la conexión viene de cloudflared (red privada)" do
    ip = remote_ip("REMOTE_ADDR" => "172.18.0.1", "HTTP_CF_CONNECTING_IP" => "203.0.113.7",
                   "HTTP_X_FORWARDED_FOR" => "198.51.100.1, 203.0.113.7")

    expect(ip).to eq("203.0.113.7")
  end

  it "ignora CF-Connecting-IP si la conexión viene de una IP pública" do
    ip = remote_ip("REMOTE_ADDR" => "198.51.100.9", "HTTP_CF_CONNECTING_IP" => "203.0.113.7")

    expect(ip).to eq("198.51.100.9")
  end

  it "ignora un CF-Connecting-IP que no es una IP" do
    ip = remote_ip("REMOTE_ADDR" => "127.0.0.1", "HTTP_CF_CONNECTING_IP" => "no-es-una-ip")

    expect(ip).to eq("127.0.0.1")
  end
end
