require "ipaddr"

# En producción todo el tráfico llega por Cloudflare Tunnel (01-arquitectura),
# así que la conexión que ve Puma es la de cloudflared, no la del cliente. Sin
# esto, request.remote_ip sería la misma para todo el mundo y los límites por
# IP de RateLimiter (RNF-SEC-005) serían uno solo, compartido por todos.
#
# Solo se hace caso a CF-Connecting-IP si la conexión viene de una red privada
# o de loopback (donde corre cloudflared); desde fuera se ignora.
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
