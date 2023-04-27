defmodule Cocktailparty.Repo.Migrations.CreateSourcesSubscriptions do
  use Ecto.Migration

  def change do
    create table(:sources_subscriptions) do
      add :source_id, references(:sources, on_delete: :nothing), null: false
      add :user_id, references(:users, on_delete: :nothing), null: false
    end

    create unique_index(:sources_subscriptions, [:source_id, :user_id])
  end
end
