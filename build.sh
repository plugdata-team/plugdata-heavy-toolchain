#!/bin/bash

./scripts/build_heavy.sh
./scripts/build_libdaisy.sh
tar -czvf Heavy.tar.xz ./Heavy/*
