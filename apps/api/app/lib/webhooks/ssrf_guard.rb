require "resolv"

# RNF-SEC-016: DNS is resolved at send time and private, loopback, link-local
# and cloud metadata IPs are rejected. It is resolved here (not when the URL is
# saved) because DNS can change in between.
module Webhooks
  module SsrfGuard
    class BlockedError < StandardError; end

    CLOUD_METADATA_IPS = %w[169.254.169.254 fd00:ec2::254].freeze

    module_function

    def check!(uri)
      raise BlockedError, "scheme not allowed" unless uri.scheme == "https"

      addresses = Resolv.getaddresses(uri.host)
      raise BlockedError, "could not resolve the host" if addresses.empty?

      addresses.each { |address| check_address!(address) }
    end

    def check_address!(address)
      ip = IPAddr.new(address)
      raise BlockedError, "cloud metadata IP" if CLOUD_METADATA_IPS.include?(address)
      raise BlockedError, "private, loopback or link-local IP" if blocked_range?(ip)
    end
    module_function :check_address!

    def blocked_range?(ip)
      ip.private? || ip.loopback? || ip.link_local?
    end
    module_function :blocked_range?
  end
end
