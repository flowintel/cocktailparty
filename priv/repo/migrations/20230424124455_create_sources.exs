defmodule Cocktailparty.Repo.Migrations.CreateSources do
  use Ecto.Migration

  def change do
    create table(:sources) do
      add :name, :string
      add :description, :string
      add :type, :string
      add :channel, :string

      timestamps()
    end

    create unique_index(:sources, [:name])
  end
end
