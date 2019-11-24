#!/bin/sh -v

# create the pulsar namespace
kubectl create ns pulsar

# deploy the clusters
kubectl -n pulsar apply -f clusters.yaml
