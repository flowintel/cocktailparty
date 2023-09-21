#!/bin/bash 

set -e
set -x

#export SECRET_KEY_BASE=REALLY_LONG_SECRET
#export DATABASE_URL=ecto://USER:PASS@HOST/database

mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
#mix phx.gen.release
MIX_ENV=prod mix release
