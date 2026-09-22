require "resolv"

# RNF-SEC-016: se resuelve el DNS en el momento del envío y se rechazan las
# IPs privadas, de loopback, link-local y de metadatos de nube. Se resuelve
# aquí (no al guardar la URL) porque el DNS puede cambiar entre medias.
module Webhooks
  module SsrfGuard
    class BlockedError < StandardError; end

    CLOUD_METADATA_IPS = %w[169.254.169.254 fd00:ec2::254].freeze

    module_function

    def check!(uri)
      raise BlockedError, "esquema no permitido" unless uri.scheme == "https"

      addresses = Resolv.getaddresses(uri.host)
      raise BlockedError, "no se ha podido resolver el host" if addresses.empty?

      addresses.each { |address| check_address!(address) }
    end

    def check_address!(address)
      ip = IPAddr.new(address)
      raise BlockedError, "IP de metadatos de nube" if CLOUD_METADATA_IPS.include?(address)
      raise BlockedError, "IP privada, loopback o link-local" if blocked_range?(ip)
    end
    module_function :check_address!

    def blocked_range?(ip)
      ip.private? || ip.loopback? || ip.link_local?
    end
    module_function :blocked_range?
  end
end
