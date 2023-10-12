defmodule Cocktailparty.Catalog.Source do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sources" do
    field :channel, :string
    field :description, :string
    field :name, :string
    field :type, :string

    many_to_many :users, Cocktailparty.Accounts.User,
      join_through: "sources_subscriptions",
      on_replace: :delete,
      on_delete: :delete_all

    belongs_to :redis_instance, Cocktailparty.Input.RedisInstance

    timestamps()
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:name, :description, :type, :channel, :redis_instance_id])
    |> validate_required([:name, :description, :type, :channel])
    |> unique_constraint(:name)
  end

  def set_redis_intance_changeset(struct, attrs \\ %{}) do
    struct
    |> cast(attrs, [:redis_instance])
    |> cast_assoc(:redis_instance)
  end
end
