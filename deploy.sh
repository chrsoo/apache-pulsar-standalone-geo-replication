#!/bin/bash
function get-mo () {
  curl -sSL https://git.io/get-mo -o mo
  chmod +x mo
}

# check if moustache bash script 'mo' is available, else download
which mo > /dev/null || get-mo

# create the pulsar namespace
kubectl apply -f spec/namespace.yaml

# creeate configuration
kubectl -n pulsar apply -f spec/config.yaml

#
for cluster in alpha beta gamma
do
  cat spec/standalone.yaml | name=${cluster} ./mo | kubectl -n pulsar apply -f -
done
