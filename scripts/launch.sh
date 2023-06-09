#!/bin/bash
export SECRET_KEY_BASE=
export DATABASE_URL=ecto://user:password@host/database
export REDIS_URI=redis://host:port/database
export PHX_HOST=
./cocktailparty/bin/server
