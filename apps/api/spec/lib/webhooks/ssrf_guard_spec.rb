require "rails_helper"

RSpec.describe Webhooks::SsrfGuard do
  def stub_dns(host, ip)
    allow(Resolv).to receive(:getaddresses).with(host).and_return([ ip ])
  end

  it "rejects private IPs (RFC1918)" do
    stub_dns("internal.example.com", "10.0.0.5")

    expect { described_class.check!(URI.parse("https://internal.example.com/hook")) }
      .to raise_error(Webhooks::SsrfGuard::BlockedError)
  end

  it "rejects loopback" do
    stub_dns("localhost.example.com", "127.0.0.1")

    expect { described_class.check!(URI.parse("https://localhost.example.com/hook")) }
      .to raise_error(Webhooks::SsrfGuard::BlockedError)
  end

  it "rejects link-local" do
    stub_dns("link.example.com", "169.254.1.1")

    expect { described_class.check!(URI.parse("https://link.example.com/hook")) }
      .to raise_error(Webhooks::SsrfGuard::BlockedError)
  end

  it "rejects the cloud metadata IP" do
    stub_dns("metadata.example.com", "169.254.169.254")

    expect { described_class.check!(URI.parse("https://metadata.example.com/hook")) }
      .to raise_error(Webhooks::SsrfGuard::BlockedError)
  end

  it "rejects schemes other than https" do
    expect { described_class.check!(URI.parse("http://example.com/hook")) }
      .to raise_error(Webhooks::SsrfGuard::BlockedError)
  end

  it "allows a normal public IP" do
    stub_dns("example.com", "93.184.216.34")

    expect { described_class.check!(URI.parse("https://example.com/hook")) }.not_to raise_error
  end
end
