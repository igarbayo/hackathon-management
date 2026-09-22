require "rails_helper"

RSpec.describe "Infraestructura (01-arquitectura)" do
  it "conecta con MongoDB y puede escribir y leer un documento" do
    collection = Mongoid.default_client[:infrastructure_smoke_test]
    collection.insert_one(ping: "pong")

    expect(collection.find(ping: "pong").count).to eq(1)
  end

  it "conecta con Redis a través de la configuración de Sidekiq" do
    Sidekiq.redis do |conn|
      expect(conn.call("PING")).to eq("PONG")
    end
  end
end
