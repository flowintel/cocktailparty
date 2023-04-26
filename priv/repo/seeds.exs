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
  channel: "dns_collector",
  description: "CIRCL pdns redis pubsub",
  name: "Passive DNS",
  type: "pubsub"
})

Cocktailparty.Repo.insert!(%Cocktailparty.Accounts.User{
  is_admin: true,
  email: "jean-louis.huynen@circl.lu",
  hashed_password: Argon2.hash_pwd_salt("FS7ivxukyNCx676")
})

Cocktailparty.Repo.insert!(%Cocktailparty.Accounts.User{
  is_admin: false,
  email: "huynenjl@gmail.com",
  hashed_password: Argon2.hash_pwd_salt("password")
})
