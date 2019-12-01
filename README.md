Beeing new to [Apache Pulsar](https://pulsar.apache.org/) I wanted to test out [geo replication](https://pulsar.apache.org/docs/en/administration-geo/) as this is a prime requirement for the cluster we are planning at work. Although [testing it in the cloud](https://streaml.io/blog/pulsar-distributed-quickstart) could be feasible I prefer having something running locally so I don't need to be too concerned about cost or giving out my credit card.


In the first attempt I followed the [Kubernetes instructions](https://pulsar.apache.org/docs/en/deploy-kubernetes/) on the pulsar web site, but quickly realised that deploying three full blown clusters on my machine, well, it made it unresponsive. So instead I set out to use a [standalone](https://pulsar.apache.org/docs/en/standalone/) condfiguration but quickly ran into trouble.

After some fiddling and with the help of the [Pulsar Users mailing list](https://lists.apache.org/list.html?users@pulsar.apache.org) I managed to get it to work. (Thanks to Sijie Guo and Brian Chandler for the help!)

As the configuration was not evident (at least to me) I thought it coudld be intersting to share it, please find the result below!


# Prerequisites
This example is based on Kubernetes and an up-and-running cluster is a prerequisite. If you don't already haver one installing [minkube](https://kubernetes.io/docs/setup/learning-environment/minikube/) or [Docker](https://docs.docker.com/) is probabley the easiest.

For this excervise I used Docker on Mac but there is no reason it would not work on other vanilla Kubernetes installations.

# Install the Kubernetes dashboard (optional)

The default Kubernetes dashboard can be useful to visualize and manage Kubernetes artifacts. It can be useful as a complement to `kubectl` on the command line.

The Kubernetes web site provides [detailed instructions](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/) on how to deploy the Kubernetes dashboard, but if you feel confident the following summary should do the trick:

1. Deploy the dashboard specified in the Kubernetes GitHub repository:
    ```
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml
    ```

1. Create [default user and role binding](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md) by executing:
    ```
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: admin-user
      namespace: kubernetes-dashboard
    EOF
    ```
    ... followed by:
    ```
    cat <<EOF | kubectl apply -f -
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: admin-user
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-admin
    subjects:
    - kind: ServiceAccount
      name: admin-user
      namespace: kubernetes-dashboard
    EOF
    ```

1. Get the auth token (one line)
    ```
    kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
    ```
    Copy the token and save it for the step below

1. Start proxy
    ```
    kubectl proxy
    ```

1. [Access the dashboard](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/.) and nter the token saved in the step above!

# Deploy Apache Pulsar
To simulate a geographically distributed Pulsar cluster we are using a multiple [standalone brokers](https://pulsar.apache.org/docs/en/standalone/) running in the same Kubernetes namespace.

Admittedly this overly simplistic, but given resource constraints on a local workstation a full-blown cluster with separate zookepper, bookies, proxies etc is probably infeasible.

From a purly functional perspeective it should not matter, however. We can still play around with the different clusters as-if they were deployed in different geographic locations.

**In order for the setup to work properly, the default broker name (`standlone`) must be globally unique or the cluster repllication will not work properly. This is done by configuring the `clusterName` option.**

To deploy the clusters run `deploy.sh` - or - do the following manually

1. Define a test namespace `pulsar``

        kubectl apply -f spec/namespace.yaml

1. Create the config resource shared by all standalone clusters

        kubectl apply -f spec/config.yaml

1. Download the [mo](https://github.com/tests-always-included/mo) bash script that replaces [moustache](https://mustache.github.io/) placeholders with envar values

        curl -sSL https://git.io/get-mo -o mo
        chmod +x mo

1. Deploy the **alpha**, **beta** and **gamma** clusters by applying [spec/standalone.yaml] once for each cluster name:

        for cluster in alpha beta gamma
        do
          cat spec/standalone.yaml | name=${cluster} ./mo | kubectl -n pulsar apply -f -
        done

The [spec/standalone.yaml] file defines a Kubernetes Service and Deployment with a `{{name}}` placeholder. If you prefer, you can create three different files and do a `kubectl -n pulsar apply -f {filename}` three times instead.

# Create alias
Apache pulsar provides `pulsar-admin` for administration and `pulsar-client` for producing and consuming test messages. The  utilities are part of the base pulsar image and can be executed by attaching to the container with `kubectl exec`, for example:

```
kubectl -n {namespace} exec {pod} -it -- bin/pulsar-admin
```
To work efficiently it is convenient to use alias and the following are assumed from here on:

* `{cluster}-admin` - adminstration of a cluster
* `{cluster}-client` - produce/consume messages for a cluster

For each shell where you want to work with the clusters you should execute `source alias.sh` in the shell.

Note that in the official Pulsar documentation for [deploying pulsar on Kubernetes](https://pulsar.apache.org/docs/en/deploy-kubernetes/), a `pulsar-admin` alias is configured to execute the `bin/pulsar-admin` binary in a container separate from the brokers. As we have a highly simpliefied with only one standalone broker per cluster we don't need this and can instead attached directly to the running broker containers. This reduces resource consumption on the local workstation or laptop.

**The next steps assumes that you are running a shell that has been configured with the alias above!**

# Configure geo replication
To configure [geo replication](https://pulsar.apache.org/docs/en/administration-geo/) we need to

* Tell each standalone cluster (**alpha**, **beta** and **gamma**) that the other clusters exist
* Configure a tenant (`acme`) and namespace (`acme/test`) that uses all three clusters for replication

1. Configure the **alpha** cluster

    Create the beta cluster in alpha:
    ```
    alpha-admin clusters create --url http://beta:8080 --broker-url pulsar://beta:6650 beta
    ```
    Create the gamma cluster in alpha:
    ```
    alpha-admin clusters create --url http://gamma:8080 --broker-url pulsar://gamma:6650 gamma
    ```
    Create the the **acme** tenant in alpha and allow it to use clusters **alpha**, **beta** and **gamma**:
    ```
    alpha-admin tenants create --allowed-clusters alpha,beta,gamma acme
    ```
    Create `acme/test` namespace in alpha:
    ```
    alpha-admin namespaces create --clusters alpha,beta,gamma acme/test
    ```

1. Configure the **beta** cluster
    ```
    beta-admin clusters create --url http://alpha:8080 --broker-url pulsar://alpha:6650 alpha

    beta-admin clusters create --url http://gamma:8080 --broker-url pulsar://gamma:6650 gamma

    beta-admin tenants create --allowed-clusters alpha,beta,gamma acme

    beta-admin namespaces create --clusters alpha,beta,gamma acme/test
    ```

1. Configure the **gamma** cluster

    ```
    gamma-admin clusters create --url http://alpha:8080 --broker-url pulsar://alpha:6650 alpha

    gamma-admin clusters create --url http://beta:8080 --broker-url pulsar://beta:6650 beta

    gamma-admin tenants create --allowed-clusters alpha,beta,gamma acme

    gamma-admin namespaces create --clusters alpha,beta,gamma acme/test
    ```

# Test geo replication
To test geo replication we create three different consumers, one for each standalone cluster and then produce messages. On successful execution all three consumers should see all messages.

Note that subscriptions are *exclusive* per default but that only applies to consumers within the same cluster.

1. Open three shells and make sure that each shell is initialized with `source alias.sh` or else the alias will not work.
1. In each shell consume 10 messages on the `acme/test/hello` topic
    ```
    alpha-client consume -n 10 -s hello acme/test/hell

    beta-client consume -n 10 -s hello acme/test/hello

    gamma-client consume -n 10 -s hello acme/test/hello
    ```
1. In a fourth shell produce 10 messages on the `acme/test/hello` topic
    ```
    alpha-client produce -n 10 -m hello acme/test/hello
    ```
1. Verify that each cluster has consumed its ten messages and then exited!
