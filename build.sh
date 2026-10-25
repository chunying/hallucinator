#!/bin/sh
BEHAVIOR="--load"
if [ "$1" = "push" ]; then
    BEHAVIOR="--platform linux/amd64,linux/arm64 --push"
fi
docker buildx build \
  -t chunyingh/hallucinator:latest \
  $BEHAVIOR \
  ./docker
