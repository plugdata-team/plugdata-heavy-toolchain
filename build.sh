#!/bin/bash

./scripts/build_heavy.sh
./scripts/build_libdaisy.sh
tar cfJ Heavy.tar.xz ./Heavy/*
