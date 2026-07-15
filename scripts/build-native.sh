#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec swift build --package-path "$ROOT/native/BladeComputerUseHelper" -c release
