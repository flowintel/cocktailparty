defmodule Cocktailparty.Repo.Migrations.CreateSinks do
  use Ecto.Migration

  def change do
    create table(:sinks) do
      add :name, :string
      add :description, :string
      add :type, :string
      add :channel, :string
      add :user_id, references(:users)

      timestamps()
    end

    create unique_index(:sinks, [:name])
  end
end
