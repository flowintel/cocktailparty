defmodule Cocktailparty.Repo.Migrations.AddUnconfirmedDefaultToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :role, :string, default: "unconfirmed", null: false
    end
  end
end
