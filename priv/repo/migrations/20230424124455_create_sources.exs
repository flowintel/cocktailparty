defmodule Cocktailparty.Repo.Migrations.CreateSources do
  use Ecto.Migration

  def change do
    create table(:sources) do
      add :name, :string
      add :description, :string
      add :driver, :string
      add :type, :string
      add :url, :string
      add :channel, :string

      timestamps()
    end
  end
end
