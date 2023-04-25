defmodule Cocktailparty.Catalog.Source do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sources" do
    field :channel, :string
    field :description, :string
    field :name, :string
    field :type, :string

    timestamps()
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:name, :description, :type, :channel])
    |> validate_required([:name, :description, :type, :channel])
    |> unique_constraint(:name)
  end

  # def subscribe(source) do
    # case get_source(source) do
    #   {:ok, pid} ->
    #     Redix.PubSub.subscribe(pid, source.channel)
    #     {:ok, pid}

    #   {:error, reason} ->
    #     {:error, reason}
    # end
  # end

end
