defmodule Cocktailparty.Input.RedisInstance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "redis_instances" do
    field :enabled, :boolean, default: false
    field :name, :string
    field :hostname, :string
    field :port, :integer

    has_many :sources, Cocktailparty.Catalog.Source

    timestamps()
  end

  @doc false
  def changeset(redis_instance, attrs) do
    redis_instance
    |> cast(attrs, [:name, :hostname, :port, :enabled])
    |> validate_required([:name, :hostname, :port, :enabled])
    |> unique_constraint(:name)
  end

  @doc """
  Starts the redis_instance Redix driver

  TODO: could returns errors
  """
  def start(redis_instance) do
    Cocktailparty.RedisInstancesDynamicSupervisor.start_child(redis_instance)
  end
end
