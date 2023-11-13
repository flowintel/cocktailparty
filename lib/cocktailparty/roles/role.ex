defmodule Cocktailparty.Roles.Role do
  use Ecto.Schema
  import Ecto.Changeset
  alias Cocktailparty.Roles.Permissions

  schema "roles" do
    field :name, :string
    embeds_one :permissions, Permissions, on_replace: :update

    has_many :users, Cocktailparty.Accounts.User

    timestamps()
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name])
    |> cast_embed(:permissions)
    |> validate_required([:name])
  end
end
