defmodule Cocktailparty.Input.RedisInstance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "redisinstances" do
    field :enabled, :boolean, default: false
    field :name, :string
    field :uri, :string

    timestamps()
  end

  @doc false
  def changeset(redis_instance, attrs) do
    redis_instance
    |> cast(attrs, [:name, :uri, :enabled])
    |> validate_required([:name, :uri, :enabled])
    |> unique_constraint(:uri)
    |> unique_constraint(:name)
  end
end
