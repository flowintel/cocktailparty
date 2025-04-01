defmodule Cocktailparty.Repo.Migrations.AddDefaultSinkFlag do
  use Ecto.Migration

  def change do
    alter table(:connections) do
      add :is_default_sink, :boolean, default: false, null: false
    end
  end
end
