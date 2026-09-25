require "ipaddr"

# In production all traffic comes through Cloudflare Tunnel (01-arquitectura),
# so the connection Puma sees is cloudflared's, not the client's. Without this,
# request.remote_ip would be the same for everyone and RateLimiter's per-IP
# limits (RNF-SEC-005) would be a single one shared by all.
#
# CF-Connecting-IP is only trusted if the connection comes from a private or
# loopback network (where cloudflared runs); from outside it is ignored.
class CloudflareRemoteIp
  HEADER = "HTTP_CF_CONNECTING_IP".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    client_ip = env[HEADER]
    if client_ip.present? && valid_ip?(client_ip) && from_trusted_proxy?(env["REMOTE_ADDR"])
      env["REMOTE_ADDR"] = client_ip
      env.delete("HTTP_X_FORWARDED_FOR")
      env.delete("HTTP_CLIENT_IP")
    end

    @app.call(env)
  end

  private

  def valid_ip?(value)
    IPAddr.new(value)
    true
  rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
    false
  end

  def from_trusted_proxy?(remote_addr)
    return false if remote_addr.blank? || !valid_ip?(remote_addr)

    ActionDispatch::RemoteIp::TRUSTED_PROXIES.any? { |range| range.include?(IPAddr.new(remote_addr)) }
  end
end
