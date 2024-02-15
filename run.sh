#!/bin/sh

# The following command works for MacOS builds with engine checked out as a peer to cabal.
flutter run --local-engine-src-path ../engine/src --local-engine-host host_debug_arm64 --local-engine host_debug_arm64
