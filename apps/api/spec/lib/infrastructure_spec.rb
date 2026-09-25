require "rails_helper"

RSpec.describe "Infrastructure (01-arquitectura)" do
  it "connects to MongoDB and can write and read a document" do
    collection = Mongoid.default_client[:infrastructure_smoke_test]
    collection.insert_one(ping: "pong")

    expect(collection.find(ping: "pong").count).to eq(1)
  end

  it "connects to Redis through the Sidekiq configuration" do
    Sidekiq.redis do |conn|
      expect(conn.call("PING")).to eq("PONG")
    end
  end
end
