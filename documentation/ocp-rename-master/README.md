
# Table of Contents

1.  [Renaming a master node](#org84c84d1)
    1.  [Verify ETCD status](#org1789fde)
    2.  [Removing the master with the wrong name from the cluster](#orga1f6f52)
    3.  [Adding the third ETCD member and OpenShift cluster member back to the cluster](#orgf2cc05d)


<a id="org84c84d1"></a>

# Renaming a master node

Let's say you've installed a new cluster and did a stupid mistake: one of your master nodes has to wrong name!

We used the great[ OCP4 helpernode](https://github.com/RedHatOfficial/ocp4-helpernode.git) ansible playbook to prepare the cluster setup and had a typo in <span class="underline">vars.yaml</span>&#x2026;

    $ oc get nodes
    NAME       STATUS   ROLES    AGE   VERSION
    master-0   Ready    master   10h   v1.19.0+7070803
    master-1   Ready    master   10h   v1.19.0+7070803
    master-3   Ready    master   10h   v1.19.0+7070803
    worker-0   Ready    worker   10h   v1.19.0+7070803
    worker-1   Ready    worker   10h   v1.19.0+7070803

We have a master node <span class="underline">master-3</span> we would like to rename to <span class="underline">master-2</span>.


<a id="org1789fde"></a>

## Verify ETCD status

First change into the openshift-etcd project:

    oc project openshift-etcd

Get the status of ETCD:

    oc get etcd -o=jsonpath='{range .items[0].status.conditions[?(@.type=="EtcdMembersAvailable")]}{.message}{"\n"}'

this should print the following message

    3 members are available

List all pods running ETCD:

    oc get -l app=etcd pods -o wide

Connect to a ETCD pod that runs on a machine that has the **correct** name

    oc rsh etcd-master-0

List ETCD members

    sh-4.4# etcdctl member list -w table
    +------------------+---------+----------+----------------------------+----------------------------+------------+
    |        ID        | STATUS  |   NAME   |         PEER ADDRS         |        CLIENT ADDRS        | IS LEARNER |
    +------------------+---------+----------+----------------------------+----------------------------+------------+
    | 15875170f1aee131 | started | master-1 | https://172.16.100.21:2380 | https://172.16.100.21:2379 |      false |
    | 385e47a681af114a | started | master-3 | https://172.16.100.22:2380 | https://172.16.100.22:2379 |      false |
    | 9bbc83dcc657b718 | started | master-0 | https://172.16.100.20:2380 | https://172.16.100.20:2379 |      false |
    +------------------+---------+----------+----------------------------+----------------------------+------------+

If all members are OK, especially the members that will stay in the
cluster (master-0 and master-1 in our case) continue with shutting
down the node we would like to replace (**master-3** in our case).


<a id="orga1f6f52"></a>

## Removing the master with the wrong name from the cluster

Connect to the master with the **wrong** name and shut it down

    $ ssh core@master-3
    $ sudo systemctl poweroff

Verify that the K8s API is still OK, this could take a while if master-3 was the main API server. Also the loadbalancer has to stop sending
traffic to master node we turned off:

    oc get nodes
    NAME       STATUS     ROLES    AGE   VERSION
    master-0   Ready      master   10h   v1.19.0+7070803
    master-1   Ready      master   10h   v1.19.0+7070803
    master-3   NotReady   master   10h   v1.19.0+7070803
    worker-0   Ready      worker   10h   v1.19.0+7070803
    worker-1   Ready      worker   10h   v1.19.0+7070803

Be patient if the command hangs for a while.

master-3 is now in the state NotReady

Connect to one of the remaining ETCD pods

    oc rsh etcd-master-0

Check the health of ETCD endpoints:

    sh-4.4# etcdctl endpoint health -w table
    {"level":"warn","ts":"2021-01-16T08:45:58.099Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"endpoint://client-ce87cb52-7f7b-4084-b073-660db7e668f6/172.16.100.22:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: all SubConns are in TransientFailure, latest connection error: connection error: desc = \"transport: Error while dialing dial tcp 172.16.100.22:2379: connect: no route to host\""}
    +----------------------------+--------+--------------+---------------------------+
    |          ENDPOINT          | HEALTH |     TOOK     |           ERROR           |
    +----------------------------+--------+--------------+---------------------------+
    | https://172.16.100.20:2379 |   true |    7.36417ms |                           |
    | https://172.16.100.21:2379 |   true |   7.432035ms |                           |
    | https://172.16.100.22:2379 |  false | 5.000180416s | context deadline exceeded |
    +----------------------------+--------+--------------+---------------------------+
    Error: unhealthy cluster

The member with IP 172.16.100.22 is unhealthy, this is our master-3 node.

Check the endpoint status of ETCD cluster members:

    sh-4.4# etcdctl endpoint status -w table
    {"level":"warn","ts":"2021-01-16T08:48:06.308Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"passthrough:///https://172.16.100.22:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: connection error: desc = \"transport: Error while dialing dial tcp 172.16.100.22:2379: connect: no route to host\""}
    Failed to get the status of endpoint https://172.16.100.22:2379 (context deadline exceeded)
    +----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    |          ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
    +----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    | https://172.16.100.20:2379 | 9bbc83dcc657b718 |   3.4.9 |   92 MB |      true |      false |        12 |     258518 |             258518 |        |
    | https://172.16.100.21:2379 | 15875170f1aee131 |   3.4.9 |   92 MB |     false |      false |        12 |     258518 |             258518 |        |
    +----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

So the member with IP 172.16.100.20 is the current leader, master-3 (172.16.100.22) is not reachable.

List the members of the cluster again:

    sh-4.4# etcdctl member list -w table
    +------------------+---------+----------+----------------------------+----------------------------+------------+
    |        ID        | STATUS  |   NAME   |         PEER ADDRS         |        CLIENT ADDRS        | IS LEARNER |
    +------------------+---------+----------+----------------------------+----------------------------+------------+
    | 15875170f1aee131 | started | master-1 | https://172.16.100.21:2380 | https://172.16.100.21:2379 |      false |
    | 385e47a681af114a | started | master-3 | https://172.16.100.22:2380 | https://172.16.100.22:2379 |      false |
    | 9bbc83dcc657b718 | started | master-0 | https://172.16.100.20:2380 | https://172.16.100.20:2379 |      false |
    +------------------+---------+----------+----------------------------+----------------------------+------------+

Now we are going to remove master-3 from the ETCD cluster.

**WARNING**: be extra careful to remove the right cluster member (master-3 in our case) in this step!

    etcdctl member remove 385e47a681af114a
    Member 385e47a681af114a removed from cluster b9e3f466bad0c744

Verify the member list again:

    sh-4.4# etcdctl member list -w table
    +------------------+---------+----------+----------------------------+----------------------------+------------+
    |        ID        | STATUS  |   NAME   |         PEER ADDRS         |        CLIENT ADDRS        | IS LEARNER |
    +------------------+---------+----------+----------------------------+----------------------------+------------+
    | 15875170f1aee131 | started | master-1 | https://172.16.100.21:2380 | https://172.16.100.21:2379 |      false |
    | 9bbc83dcc657b718 | started | master-0 | https://172.16.100.20:2380 | https://172.16.100.20:2379 |      false |
    +------------------+---------+----------+----------------------------+----------------------------+------------+

Remove the master node from OpenShift:

    oc delete node master-3

**WARNING**: As the cluster will reconfigure itself after this step it is possible that API request fail for example

       oc get co
    Error from server (InternalError): an error on the server ("") has prevented the request from succeeding (get clusteroperators.config.openshift.io)

You have to be patient, everything should work again after a few minutes

Check the state of cluster operators:

    oc get co
    NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
    authentication                             4.6.8     True        False         False      15m
    cloud-credential                           4.6.8     True        False         False      10h
    cluster-autoscaler                         4.6.8     True        False         False      10h
    config-operator                            4.6.8     True        False         False      10h
    console                                    4.6.8     True        False         False      9h
    csi-snapshot-controller                    4.6.8     True        False         False      9h
    dns                                        4.6.8     True        False         False      10h
    etcd                                       4.6.8     True        True          False      10h
    image-registry                             4.6.8     True        False         False      10h
    ingress                                    4.6.8     True        False         False      10h
    insights                                   4.6.8     True        False         False      10h
    kube-apiserver                             4.6.8     True        False         False      10h
    kube-controller-manager                    4.6.8     True        False         False      10h
    kube-scheduler                             4.6.8     True        False         False      10h
    kube-storage-version-migrator              4.6.8     True        False         False      9h
    machine-api                                4.6.8     True        False         False      10h
    machine-approver                           4.6.8     True        False         False      10h
    machine-config                             4.6.8     True        False         False      2m34s
    marketplace                                4.6.8     True        False         False      9h
    monitoring                                 4.6.8     False       True          True       2m23s
    network                                    4.6.8     True        False         False      10h
    node-tuning                                4.6.8     True        False         False      10h
    openshift-apiserver                        4.6.8     True        True          False      15m
    openshift-controller-manager               4.6.8     True        False         False      10h
    openshift-samples                          4.6.8     True        False         False      10h
    operator-lifecycle-manager                 4.6.8     True        False         False      10h
    operator-lifecycle-manager-catalog         4.6.8     True        False         False      10h
    operator-lifecycle-manager-packageserver   4.6.8     True        False         False      9h
    service-ca                                 4.6.8     True        False         False      10h
    storage                                    4.6.8     True        False         False      10h

The ETCD cluster operator will stay in the degraded state as long as there's no third cluster member. This is expected!

    oc describe co etcd
    .
    .
    .
        Message: ScriptControllerDegraded: "configmap/etcd-pod": missing env var values EnvVarControllerDegraded: at least three nodes are required to have a valid configuration
    .
    .
    .

Remove remaining ETCD secrets in the OpenShift namespace

    oc delete secret -n openshift-etcd etcd-peer-master-3
    oc delete secret -n openshift-etcd etcd-serving-master-3
    oc delete secret -n openshift-etcd etcd-serving-metrics-master-3


<a id="orgf2cc05d"></a>

## Adding the third ETCD member and OpenShift cluster member back to the cluster

Reinstall the third master with the correct name. If you are using [OCP4 helpernode](https://github.com/RedHatOfficial/ocp4-helpernode.git), fix the name of the master in vars.yaml and apply the playbook gain

    ansible-playbook tasks/main.yml -e @vars.yaml

Reinstall the third master and wait for the CSR:

    # oc get csr
    NAME        AGE   SIGNERNAME                                    REQUESTOR                                                                   CONDITION
    csr-k54wk   94s   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Pending

Sign the CSR:

    oc adm certificate approve csr-k54wk
    certificatesigningrequest.certificates.k8s.io/csr-k54wk approved

Wait for the second CSR and sign it:

    # oc get csr |grep Pending
    csr-t54rb   21s     kubernetes.io/kubelet-serving                 system:node:master-2                                                        Pending
    # oc adm certificate approve csr-t54rb
    certificatesigningrequest.certificates.k8s.io/csr-t54rb approved

Verify cluster nodes:

    # oc get nodes
    NAME       STATUS   ROLES    AGE   VERSION
    master-0   Ready    master   11h   v1.19.0+7070803
    master-1   Ready    master   11h   v1.19.0+7070803
    master-2   Ready    master   79s   v1.19.0+7070803
    worker-0   Ready    worker   10h   v1.19.0+7070803
    worker-1   Ready    worker   10h   v1.19.0+7070803

**master-2** successfully joined the cluster!

Verify the number of ETCD members:

    # oc get etcd -o=jsonpath='{range .items[0].status.conditions[?(@.type=="EtcdMembersAvailable")]}{.message}{"\n"}'
    3 members are available

Verify ETCD status in one of the etcd pods, we could select the new cluster member master-2 for our tests:

    # oc get -l app=etcd pods -o wide
    NAME            READY   STATUS    RESTARTS   AGE     IP              NODE       NOMINATED NODE   READINESS GATES
    etcd-master-0   3/3     Running   0          2m8s    172.16.100.20   master-0   <none>           <none>
    etcd-master-1   3/3     Running   0          101s    172.16.100.21   master-1   <none>           <none>
    etcd-master-2   3/3     Running   0          2m35s   172.16.100.22   master-2   <none>           <none>
    # oc rsh etcd-master-2
    sh-4.4# etcdctl member list -w table
    +------------------+---------+----------+----------------------------+----------------------------+------------+
    |        ID        | STATUS  |   NAME   |         PEER ADDRS         |        CLIENT ADDRS        | IS LEARNER |
    +------------------+---------+----------+----------------------------+----------------------------+------------+
    | 15875170f1aee131 | started | master-1 | https://172.16.100.21:2380 | https://172.16.100.21:2379 |      false |
    | 69730a0d0968d36e | started | master-2 | https://172.16.100.22:2380 | https://172.16.100.22:2379 |      false |
    | 9bbc83dcc657b718 | started | master-0 | https://172.16.100.20:2380 | https://172.16.100.20:2379 |      false |
    +------------------+---------+----------+----------------------------+----------------------------+------------+
    sh-4.4# etcdctl endpoint status -w table
    +----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    |          ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
    +----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    | https://172.16.100.20:2379 | 9bbc83dcc657b718 |   3.4.9 |   92 MB |     false |      false |        61 |     269849 |             269849 |        |
    | https://172.16.100.21:2379 | 15875170f1aee131 |   3.4.9 |   92 MB |     false |      false |        61 |     269849 |             269849 |        |
    | https://172.16.100.22:2379 | 69730a0d0968d36e |   3.4.9 |   92 MB |      true |      false |        61 |     269849 |             269849 |        |
    +----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    sh-4.4# etcdctl endpoint health -w table
    +----------------------------+--------+-------------+-------+
    |          ENDPOINT          | HEALTH |    TOOK     | ERROR |
    +----------------------------+--------+-------------+-------+
    | https://172.16.100.20:2379 |   true |  9.296099ms |       |
    | https://172.16.100.22:2379 |   true |  9.966355ms |       |
    | https://172.16.100.21:2379 |   true | 10.589346ms |       |
    +----------------------------+--------+-------------+-------+

Verify all cluster operators are ok. WAIT and be PATIENT if there are cluster operators progressing!

    # oc get co
    NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
    authentication                             4.6.8     True        False         False      23m
    cloud-credential                           4.6.8     True        False         False      11h
    cluster-autoscaler                         4.6.8     True        False         False      11h
    config-operator                            4.6.8     True        False         False      11h
    console                                    4.6.8     True        False         False      10h
    csi-snapshot-controller                    4.6.8     True        False         False      10h
    dns                                        4.6.8     True        False         False      11h
    etcd                                       4.6.8     True        False         False      11h
    image-registry                             4.6.8     True        False         False      11h
    ingress                                    4.6.8     True        False         False      11h
    insights                                   4.6.8     True        False         False      11h
    kube-apiserver                             4.6.8     True        False         False      11h
    kube-controller-manager                    4.6.8     True        False         False      11h
    kube-scheduler                             4.6.8     True        False         False      11h
    kube-storage-version-migrator              4.6.8     True        False         False      10h
    machine-api                                4.6.8     True        False         False      11h
    machine-approver                           4.6.8     True        False         False      11h
    machine-config                             4.6.8     True        False         False      26m
    marketplace                                4.6.8     True        False         False      10h
    monitoring                                 4.6.8     True        False         False      20m
    network                                    4.6.8     True        False         False      11h
    node-tuning                                4.6.8     True        False         False      10h
    openshift-apiserver                        4.6.8     True        False         False      38m
    openshift-controller-manager               4.6.8     True        False         False      10h
    openshift-samples                          4.6.8     True        False         False      10h
    operator-lifecycle-manager                 4.6.8     True        False         False      11h
    operator-lifecycle-manager-catalog         4.6.8     True        False         False      11h
    operator-lifecycle-manager-packageserver   4.6.8     True        False         False      18m
    service-ca                                 4.6.8     True        False         False      11h
    storage                                    4.6.8     True        False         False      11h

Just to be sure verify the cluster version:

    # oc get clusterversions.config.openshift.io
    NAME      VERSION   AVAILABLE   PROGRESSING   SINCE   STATUS
    version   4.6.8     True        False         10h     Cluster version is 4.6.8

**FINE**
