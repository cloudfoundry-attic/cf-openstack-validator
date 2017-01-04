#!/bin/bash

set -e

DOCKER_IMAGE=${DOCKER_IMAGE:-boshcpi/cf-openstack-validator-ci}

docker login

echo "Download latest docker image..."
docker pull $DOCKER_IMAGE

echo "Tagging 'latest' to 'previous'..."
docker tag $DOCKER_IMAGE $DOCKER_IMAGE:previous

echo "Building docker image..."
docker build -t $DOCKER_IMAGE .

echo "Pushing docker images to '$DOCKER_IMAGE'..."
docker push $DOCKER_IMAGE
