#!/bin/sh -v

# make sure the alias are present
source alias.sh

## configure alpha cluster
# create the beta and gamma clusters in alpha
alpha-admin clusters create --url http://beta:8080 --broker-url pulsar://beta:6650 beta
alpha-admin clusters create --url http://gamma:8080 --broker-url pulsar://gamma:6650 gamma

# create the the `acme` tenant in alpha and allow it to use clusters alpha, beta and gamma
alpha-admin tenants create --allowed-clusters alpha,beta,gamma acme

# create `acme/test` namespace in alpha
alpha-admin namespaces create --clusters alpha,beta,gamma acme/test

## configure beta cluster
# create the alpha and gamma clusters in beta
beta-admin clusters create --url http://alpha:8080 --broker-url pulsar://alpha:6650 alpha
beta-admin clusters create --url http://gamma:8080 --broker-url pulsar://gamma:6650 gamma

# create the the `acme` tenant in beta and allow it to use clusters alpha, beta and gamma
beta-admin tenants create --allowed-clusters alpha,beta,gamma acme

# create `acme/test` namespace in beta
beta-admin namespaces create --clusters alpha,beta,gamma acme/test

## configure gamma cluster
# create the alpha and beta clusters in gamma
gamma-admin clusters create --url http://alpha:8080 --broker-url pulsar://alpha:6650 alpha
gamma-admin clusters create --url http://beta:8080 --broker-url pulsar://beta:6650 beta

# create the the `acme` tenant in beta and allow it to use clusters alpha, beta and gamma
gamma-admin tenants create --allowed-clusters alpha,beta,gamma acme

# create `acme/test` namespace in beta
gamma-admin namespaces create --clusters alpha,beta,gamma acme/test
