#!/bin/bash

set -e
set -x

mix deps.get
pushd assets/
npm install
popd
