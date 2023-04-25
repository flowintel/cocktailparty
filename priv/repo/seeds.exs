# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Cocktailparty.Repo.insert!(%Cocktailparty.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

Cocktailparty.Repo.insert!(%Cocktailparty.Catalog.Source{
  channel: "dns-collector",
  description: "CIRCL pdns redis pubsub",
  name: "Passive DNS",
  type: "pubsub"
})
