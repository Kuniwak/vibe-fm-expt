#!/usr/bin/env bash
# Build the workspace images (targets a and b) and the network-namespace holder image.
# No provenance/SBOM attestations, so the image ID depends only on image content.
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"
docker build --provenance=false --sbom=false --target a -t "${IMAGE_A:-devenv:latest}" "$ROOT/image"
docker build --provenance=false --sbom=false --target b -t "${IMAGE_B:-devenv-b:latest}" "$ROOT/image"
docker build --provenance=false --sbom=false -t "$NET_IMAGE" "$ROOT/netguard"
