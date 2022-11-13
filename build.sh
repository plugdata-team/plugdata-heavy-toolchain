#!/bin/bash

./scripts/build_heavy.sh
./scripts/build_libdaisy.sh

echo "v0.0.2" > ./Heavy/VERSION
