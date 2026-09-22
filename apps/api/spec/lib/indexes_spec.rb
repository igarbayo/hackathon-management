require "rails_helper"

RSpec.describe "Índices Mongoid (02-modelo-datos)" do
  it "todos los modelos pueden crear sus índices en MongoDB sin conflicto" do
    expect { Mongoid::Tasks::Database.create_indexes }.not_to raise_error
  end
end
