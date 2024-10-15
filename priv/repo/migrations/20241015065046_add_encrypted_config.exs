defmodule Cocktailparty.Repo.Migrations.AddEncryptedConfig do
  use Ecto.Migration

  def up do
    alter table(:connections) do
      remove :config
      add :config, :binary
    end
  end
  def down do
    alter table(:connections) do
      remove :config
      add :config, :map, null: false, default: %{}
    end
  end
end
