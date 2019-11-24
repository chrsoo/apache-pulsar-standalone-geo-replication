#!/bin/sh

kubectl create ns pulsar
kubectl -n pulsar apply -f clusters.yaml
