require "rails_helper"

RSpec.describe "Mongoid indexes (02-modelo-datos)" do
  it "every model can create its indexes in MongoDB with no conflict" do
    expect { Mongoid::Tasks::Database.create_indexes }.not_to raise_error
  end
end
