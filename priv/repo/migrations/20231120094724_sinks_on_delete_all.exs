defmodule Cocktailparty.Repo.Migrations.SinksOnDeleteAll do
  use Ecto.Migration

  def change do
    alter table(:sinks) do
      modify :user_id, references(:users, on_delete: :delete_all),
        from: references(:users, on_delete: :nothing)
    end
  end
end
