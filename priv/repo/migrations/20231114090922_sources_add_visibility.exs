defmodule Cocktailparty.Repo.Migrations.SourcesAddVisibility do
  use Ecto.Migration

  def change do
    alter table(:sources) do
      add :public, :boolean, default: false
    end
  end
end
