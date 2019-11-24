#!/bin/sh

# pulsar-client alias
alias alpha-admin='kubectl -n pulsar exec alpha -it -- bin/pulsar-admin'
alias beta-admin='kubectl -n pulsar exec beta -it -- bin/pulsar-admin'
alias gamma-admin='kubectl -n pulsar exec gamma -it -- bin/pulsar-admin'

# pulsar-client alias
alias alpha-client='kubectl -n pulsar exec alpha -it -- bin/pulsar-client'
alias beta-client='kubectl -n pulsar exec beta -it -- bin/pulsar-client'
alias gamma-client='kubectl -n pulsar exec gamma -it -- bin/pulsar-client'
