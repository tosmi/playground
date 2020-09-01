
# Table of Contents

1.  [Backup / restore tests](#org93bc24d)
    1.  [first test replacing unhealth member](#orgeab6d39)
    2.  [second test Restoring to a previous cluster state](#org232bf3f)

We tested 2 scenarios:

-   losing a single control plane host
-   losing 2 out of 3 control plane hosts


<a id="org93bc24d"></a>

# Backup / restore tests

collect etcd member list, just to be sure

    oc project openshift-etcd
    etctctl member list

    fc527668531fd0, started, master02, https://10.0.0.183:2380, https://10.0.0.183:2379, false
    866b1732ab61f1d6, started, master03, https://10.0.0.184:2380, https://10.0.0.184:2379, false
    b061c3a7cd643408, started, master01, https://10.0.0.182:2380, https://10.0.0.182:2379, false


<a id="orgeab6d39"></a>

## first test [replacing unhealth member](https://docs.openshift.com/container-platform/4.5/backup_and_restore/replacing-unhealthy-etcd-member.html#replacing-unhealthy-etcd-member)

shutdown and destroy master03

    virsh destroy master03

list etcd members

    ETCDCTL_API=3 nsenter -n -p -m -t 2494 -- etcdctl member list --write-out=table --endpoints=https://10.0.0.182:2379,https://10.0.0.183:2379,https://10.0.0.184:2379 --cert=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.crt --key=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.key --cacert=/etc/kubernetes/static-pod-certs/configmaps/etcd-serving-ca/ca-bundle.crt

    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |        ID        | STATUS  |   NAME   |       PEER ADDRS        |      CLIENT ADDRS       | IS LEARNER |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |  efc527668531fd0 | started | master02 | https://10.0.0.183:2380 | https://10.0.0.183:2379 |      false |
    | 866b1732ab61f1d6 | started | master03 | https://10.0.0.184:2380 | https://10.0.0.184:2379 |      false |
    | b061c3a7cd643408 | started | master01 | https://10.0.0.182:2380 | https://10.0.0.182:2379 |      false |
    +------------------+---------+----------+-------------------------+-------------------------+------------+

    ETCDCTL_API=3 nsenter -n -p -m -t 2494 -- etcdctl endpoint status --write-out=table --endpoints=https://10.0.0.182:2379,https://10.0.0.183:2379,https://10.0.0.184:2379 --cert=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.crt --key=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.key --cacert=/etc/kubernetes/static-pod-certs/configmaps/etcd-serving-ca/ca-bundle.crt

status after one node is down

    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    |        ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    | https://10.0.0.182:2379 | b061c3a7cd643408 |   3.4.9 |   78 MB |     false |      false |        55 |    1553178 |            1553178 |        |
    | https://10.0.0.183:2379 |  efc527668531fd0 |   3.4.9 |   78 MB |      true |      false |        55 |    1553178 |            1553178 |        |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

undefined and recreated master03

    virsh undefine master03
    ansible-playbook -K playbooks/ocp/ocp4_local_bridge.yml

IMHO this will fail because we did not remove the old master03 from openshift (oc delete node)

    Aug 31 14:39:11 master03 hyperkube[1443]: E0831 14:39:11.507636    1443 kubelet_node_status.go:92] Unable to register node "master03" with API server: nodes is forbidden: User "system:anonymous" cannot create resource "csinodes" in API group "storage.k8s.io" at the cluster scope

some requests time out

    oc adm certificate approve csr-fdbmv
    No resources found
    Error from server: etcdserver: request timed out

executing the command a second time works

deleted node with

    oc delete node master03

signed csrs

    oc adm certificate approve csr-fdbmv
    oc adm certificate approve csr-8hwl7
    oc get csr
    NAME        AGE     SIGNERNAME                                    REQUESTOR                                                                   CONDITION
    csr-8hwl7   108s    kubernetes.io/kubelet-serving                 system:node:master03                                                        Approved,Issued
    csr-fdbmv   9m50s   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Approved,Issued

clusteroperators are progressing, got a new static pod definition for etcd

    oc get clusteroperators
    NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
    authentication                             4.5.7     True        False         False      5d4h
    cloud-credential                           4.5.7     True        False         False      5d6h
    cluster-autoscaler                         4.5.7     True        False         False      5d5h
    config-operator                            4.5.7     True        False         False      5d5h
    console                                    4.5.7     True        False         False      7h29m
    csi-snapshot-controller                    4.5.7     True        False         False      3d14h
    dns                                        4.5.7     True        True          False      5d5h
    etcd                                       4.5.7     True        True          True       5d5h
    image-registry                             4.5.7     True        False         True       5d5h
    ingress                                    4.5.7     True        False         False      7h29m
    insights                                   4.5.7     True        False         False      5d5h
    kube-apiserver                             4.5.7     True        True          True       5d5h
    kube-controller-manager                    4.5.7     True        True          True       5d5h
    kube-scheduler                             4.5.7     True        True          True       5d5h
    kube-storage-version-migrator              4.5.7     True        False         False      25m
    machine-api                                4.5.7     True        False         False      5d5h
    machine-approver                           4.5.7     True        False         False      5d5h
    machine-config                             4.5.7     True        False         False      4m50s
    marketplace                                4.5.7     True        False         False      7h29m
    monitoring                                 4.5.7     True        False         False      4m7s
    network                                    4.5.7     True        True          False      5d5h
    node-tuning                                4.5.7     True        False         False      3d19h
    openshift-apiserver                        4.5.7     True        False         True       4m52s
    openshift-controller-manager               4.5.7     True        False         False      5d2h
    openshift-samples                          4.5.7     True        False         False      3d19h
    operator-lifecycle-manager                 4.5.7     True        False         False      5d5h
    operator-lifecycle-manager-catalog         4.5.7     True        False         False      5d5h
    operator-lifecycle-manager-packageserver   4.5.7     True        False         False      7h29m
    service-ca                                 4.5.7     True        False         False      5d5h
    storage                                    4.5.7     True        False         False      3d19h

pods are starting up on master03 but no pod definition for etcd. after 2-3 minutes etcd is starting up.

etcd done, kube-apiserver is still progressing


<a id="org232bf3f"></a>

## second test [Restoring to a previous cluster state](https://docs.openshift.com/container-platform/4.5/backup_and_restore/disaster_recovery/scenario-2-restoring-cluster-state.html)

etcd member list:

    ETCDCTL_API=3 nsenter -n -p -m -t 835256 -- etcdctl member list --write-out=table --endpoints=https://10.0.0.182:2379,https://10.0.0.183:2379,https://10.0.0.184:2379 --cert=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.crt --key=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.key --cacert=/etc/kubernetes/static-pod-certs/configmaps/etcd-serving-ca/ca-bundle.crt
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |        ID        | STATUS  |   NAME   |       PEER ADDRS        |      CLIENT ADDRS       | IS LEARNER |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |  efc527668531fd0 | started | master02 | https://10.0.0.183:2380 | https://10.0.0.183:2379 |      false |
    | 866b1732ab61f1d6 | started | master03 | https://10.0.0.184:2380 | https://10.0.0.184:2379 |      false |
    | b061c3a7cd643408 | started | master01 | https://10.0.0.182:2380 | https://10.0.0.182:2379 |      false |
    +------------------+---------+----------+-------------------------+-------------------------+------------+

etcd endpoint status

    ETCDCTL_API=3 nsenter -n -p -m -t 835256 -- etcdctl endpoint status --write-out=table --endpoints=https://10.0.0.182:2379,https://10.0.0.183:2379,https://10.0.0.184:2379 --cert=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.crt --key=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.key --cacert=/etc/kubernetes/static-pod-certs/configmaps/etcd-serving-ca/ca-bundle.crt
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    |        ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    | https://10.0.0.182:2379 | b061c3a7cd643408 |   3.4.9 |   78 MB |     false |      false |        75 |    1571407 |            1571407 |        |
    | https://10.0.0.183:2379 |  efc527668531fd0 |   3.4.9 |   78 MB |     false |      false |        75 |    1571408 |            1571408 |        |
    | https://10.0.0.184:2379 | 866b1732ab61f1d6 |   3.4.9 |   78 MB |      true |      false |        75 |    1571408 |            1571408 |        |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

created backup of master01 and rsynced files to other host

    /usr/local/bin/cluster-backup.sh /var/home/core/assets/

destroy master03 with

    virsh destroy master03

commands start hanging, after 2-3 minutes cluster works as normal

etcd status

    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    |        ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    | https://10.0.0.182:2379 | b061c3a7cd643408 |   3.4.9 |   78 MB |     false |      false |        77 |    1930250 |            1930250 |        |
    | https://10.0.0.183:2379 |  efc527668531fd0 |   3.4.9 |   78 MB |      true |      false |        77 |    1930250 |            1930250 |        |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

etcd member list

    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |        ID        | STATUS  |   NAME   |       PEER ADDRS        |      CLIENT ADDRS       | IS LEARNER |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |  efc527668531fd0 | started | master02 | https://10.0.0.183:2380 | https://10.0.0.183:2379 |      false |
    | 866b1732ab61f1d6 | started | master03 | https://10.0.0.184:2380 | https://10.0.0.184:2379 |      false |
    | b061c3a7cd643408 | started | master01 | https://10.0.0.182:2380 | https://10.0.0.182:2379 |      false |
    +------------------+---------+----------+-------------------------+-------------------------+------------+

destroy master02 with

    virsh destroy master02

etcd status

    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+-----------------------+
    |        ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX |        ERRORS         |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+-----------------------+
    | https://10.0.0.182:2379 | b061c3a7cd643408 |   3.4.9 |   78 MB |     false |      false |        77 |    1931061 |            1931061 | etcdserver: no leader |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+-----------------------+

member list

    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |        ID        | STATUS  |   NAME   |       PEER ADDRS        |      CLIENT ADDRS       | IS LEARNER |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |  efc527668531fd0 | started | master02 | https://10.0.0.183:2380 | https://10.0.0.183:2379 |      false |
    | 866b1732ab61f1d6 | started | master03 | https://10.0.0.184:2380 | https://10.0.0.184:2379 |      false |
    | b061c3a7cd643408 | started | master01 | https://10.0.0.182:2380 | https://10.0.0.182:2379 |      false |
    +------------------+---------+----------+-------------------------+-------------------------+------------+

undefined  master02 and master03 so they need to be reinstalled

followed [Restoring to a previous cluster state](https://docs.openshift.com/container-platform/4.5/backup_and_restore/disaster_recovery/scenario-2-restoring-cluster-state.html) and created single node etcd cluster

    mv /etc/kubernetes/manifests/etcd-pod.yaml /tmp
    crictl ps |grep etcd

output:

    1c719c84304e0       d1eec47fd97e5adda38c64780292df9c2eae0f260c0c26ed501822fbd2eb6d8b   16 hours ago         Running             etcdctl                                       0                   c606765487d00

etcd pod is gone

disabled kube-apiserer

    mv /etc/kubernetes/manifests/kube-apiserver-pod.yaml /tmp/

kube-apiserver got restarted

    crictl ps |grep apiserver
    bac9986e2b821       d8375a61d36e3b902b241c3b3badc2f4634e4ebb64bcbc9bc613999328f93a37   5 seconds ago       Running             kube-apiserver                                4                   f2ed613c93da7
    f876aefd586ff       aa16d616ec3d5de5ded45d346fee2b7a7da2d830e85a85dcbdd1eb58cf6e8921   16 hours ago        Running             openshift-apiserver                           0                   2a9ff0b9d5e1a

but finally died after a few seconds

    crictl ps |grep apiserver
    f876aefd586ff       aa16d616ec3d5de5ded45d346fee2b7a7da2d830e85a85dcbdd1eb58cf6e8921   17 hours ago        Running             openshift-apiserver                           0                   2a9ff0b9d5e1a

moved /var/lib/etcd

    mv /var/lib/etcd/ /tmp/

copied one backup to <span class="underline">/home/core/assets/restore</span> and executed

    [root@master01 manifests]# /usr/local/bin/cluster-restore.sh /home/core/assets/restore/
    ...stopping kube-apiserver-pod.yaml
    ...stopping kube-controller-manager-pod.yaml
    ...stopping kube-scheduler-pod.yaml
    ...stopping etcd-pod.yaml
    Waiting for container etcd to stop
    complete
    Waiting for container etcdctl to stop
    complete
    Waiting for container etcd-metrics to stop
    complete
    Waiting for container kube-controller-manager to stop
    complete
    Waiting for container kube-apiserver to stop
    complete
    Waiting for container kube-scheduler to stop
    complete
    starting restore-etcd static pod
    starting kube-apiserver-pod.yaml
    static-pod-resources/kube-apiserver-pod-15/kube-apiserver-pod.yaml
    starting kube-controller-manager-pod.yaml
    static-pod-resources/kube-controller-manager-pod-6/kube-controller-manager-pod.yaml
    starting kube-scheduler-pod.yaml
    static-pod-resources/kube-scheduler-pod-9/kube-scheduler-pod.yaml

inspected etcd pod and did a member list

    root@master01 manifests]# crictl ps |grep etcd
    90288f98c4a2a       d1eec47fd97e5adda38c64780292df9c2eae0f260c0c26ed501822fbd2eb6d8b   58 seconds ago      Running             etcd                                          0                   ffa8c066cc020
    [root@master01 manifests]# crictl inspect etcd |grep pid
    FATA[0000] Getting the status of the container "etcd" failed: rpc error: code = NotFound desc = could not find container "etcd": container with ID starting with etcd not found: ID does not exist
    [root@master01 manifests]# crictl inspect 90288f98c4a2a |grep pid
        "pid": 2634801,
    	  "pids": {
    	    "type": "pid"
    [root@master01 manifests]# ETCDCTL_API=3 nsenter -n -p -m -t 2634801 -- etcdctl member list --write-out=table --endpoints=https://10.0.0.182:2379,https://10.0.0.183:2379,https://10.0.0.184:2379 --cert=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.crt --key=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.key --cacert=/etc/kubernetes/static-pod-certs/configmaps/etcd-serving-ca/ca-bundle.crt
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |        ID        | STATUS  |   NAME   |       PEER ADDRS        |      CLIENT ADDRS       | IS LEARNER |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    | 6d0ac07810a4b7be | started | master01 | https://10.0.0.182:2380 | https://10.0.0.182:2379 |      false |
    +------------------+---------+----------+-------------------------+-------------------------+------------+

so we have a one node etcd running

restarted the kublet service on the master

    systemctl restart kubelet

oc commands started working again

    [root@bastion ~]# oc get clusteroperators
    NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
    authentication                             4.5.7     True        False         False      5d21h
    cloud-credential                           4.5.7     True        False         False      5d22h
    cluster-autoscaler                         4.5.7     True        False         False      5d22h
    config-operator                            4.5.7     True        False         False      5d22h
    console                                    4.5.7     False       False         False      48s
    csi-snapshot-controller                    4.5.7     True        False         False      4d7h
    dns                                        4.5.7     True        False         False      5d22h
    etcd                                       4.5.7     True        False         False      5d22h
    image-registry                             4.5.7     True        False         True       5d22h
    ingress                                    4.5.7     True        False         False      24h
    insights                                   4.5.7     True        False         False      5d22h
    kube-apiserver                             4.5.7     True        False         False      5d22h
    kube-controller-manager                    4.5.7     True        False         False      5d22h
    kube-scheduler                             4.5.7     True        False         False      5d22h
    kube-storage-version-migrator              4.5.7     True        False         False      17h
    machine-api                                4.5.7     True        False         False      5d22h
    machine-approver                           4.5.7     True        False         False      5d22h
    machine-config                             4.5.7     True        False         False      16h
    marketplace                                4.5.7     True        False         False      24h
    monitoring                                 4.5.7     True        False         False      16h
    network                                    4.5.7     True        False         False      5d22h
    node-tuning                                4.5.7     True        False         False      4d12h
    openshift-apiserver                        4.5.7     True        False         False      16h
    openshift-controller-manager               4.5.7     True        False         False      5d19h
    openshift-samples                          4.5.7     True        False         False      4d12h
    operator-lifecycle-manager                 4.5.7     True        False         False      5d22h
    operator-lifecycle-manager-catalog         4.5.7     True        False         False      5d22h
    operator-lifecycle-manager-packageserver   4.5.7     True        False         False      24h
    service-ca                                 4.5.7     True        False         False      5d22h
    storage                                    4.5.7     True        False         False      4d12h
    [root@bastion ~]#

seem like cluster is healthy, after a few seconds kube-apiserver, kube-control-manager start progessing

    [root@bastion ~]# oc get clusteroperators
    NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
    authentication                             4.5.7     True        False         False      5d21h
    cloud-credential                           4.5.7     True        False         False      5d22h
    cluster-autoscaler                         4.5.7     True        False         False      5d22h
    config-operator                            4.5.7     True        False         False      5d22h
    console                                    4.5.7     False       False         False      2m33s
    csi-snapshot-controller                    4.5.7     True        True          False      4d7h
    dns                                        4.5.7     True        True          True       5d22h
    etcd                                       4.5.7     True        False         False      5d22h
    image-registry                             4.5.7     True        False         True       5d22h
    ingress                                    4.5.7     True        False         False      24h
    insights                                   4.5.7     True        False         False      5d22h
    kube-apiserver                             4.5.7     True        True          False      5d22h
    kube-controller-manager                    4.5.7     True        True          False      5d22h
    kube-scheduler                             4.5.7     True        True          False      5d22h
    kube-storage-version-migrator              4.5.7     True        False         False      17h
    machine-api                                4.5.7     True        False         False      5d22h
    machine-approver                           4.5.7     True        False         False      5d22h
    machine-config                             4.5.7     True        False         False      16h
    marketplace                                4.5.7     True        False         False      24h
    monitoring                                 4.5.7     True        False         False      16h
    network                                    4.5.7     True        False         False      5d22h
    node-tuning                                4.5.7     True        False         False      4d12h
    openshift-apiserver                        4.5.7     True        False         False      16h
    openshift-controller-manager               4.5.7     True        False         False      5d19h
    openshift-samples                          4.5.7     True        False         False      4d12h
    operator-lifecycle-manager                 4.5.7     True        False         False      5d22h
    operator-lifecycle-manager-catalog         4.5.7     True        False         False      5d22h
    operator-lifecycle-manager-packageserver   4.5.7     True        False         False      24h
    service-ca                                 4.5.7     True        False         False      5d22h
    storage                                    4.5.7     True        False         False      4d12h

the reason is that master02 and master03 are still members of the cluster:

    [root@bastion ~]# oc get nodes
    NAME       STATUS     ROLES    AGE     VERSION
    infra01    Ready      worker   5d21h   v1.18.3+2cf11e2
    infra02    Ready      worker   5d21h   v1.18.3+2cf11e2
    master01   Ready      master   5d22h   v1.18.3+2cf11e2
    master02   NotReady   master   5d22h   v1.18.3+2cf11e2
    master03   NotReady   master   16h     v1.18.3+2cf11e2
    worker01   Ready      worker   5d21h   v1.18.3+2cf11e2
    worker02   Ready      worker   5d21h   v1.18.3+2cf11e2

    oc describe clusteroperator kube-apiserver |grep Message
        Message:               NodeControllerDegraded: The master nodes not ready: node "master02" not ready since 2020-09-01 07:25:11 +0000 UTC because NodeStatusUnknown (Kubelet stopped posting node status.), node "master03" not ready since 2020-09-01 07:25:11 +0000 UTC because NodeStatusUnknown (Kubelet stopped posting node status.)
        Message:               NodeInstallerProgressing: 3 nodes are at revision 15; 0 nodes have achieved new revision 16
        Message:               StaticPodsAvailable: 3 nodes are active; 3 nodes are at revision 15; 0 nodes have achieved new revision 16

deleted nodes master02 and master03 from cluster

    [root@bastion ~]# oc delete node master02
    node "master02" deleted
    [root@bastion ~]# oc delete node master03
    node "master03" deleted

    [root@bastion ~]# oc get nodes
    NAME       STATUS   ROLES    AGE     VERSION
    infra01    Ready    worker   5d21h   v1.18.3+2cf11e2
    infra02    Ready    worker   5d21h   v1.18.3+2cf11e2
    master01   Ready    master   5d22h   v1.18.3+2cf11e2
    worker01   Ready    worker   5d21h   v1.18.3+2cf11e2
    worker02   Ready    worker   5d21h   v1.18.3+2cf11e2

oc commands started to hang

just to be sure checked the state of etcd on master01 again

    [root@master01 manifests]# crictl ps |grep etcd794e7b0afc21c       d1eec47fd97e5adda38c64780292df9c2eae0f260c0c26ed501822fbd2eb6d8b   About a minute ago   Running             etcd-metrics                                  0                   19b10671d35c0ed5bedcf1715a       d1eec47fd97e5adda38c64780292df9c2eae0f260c0c26ed501822fbd2eb6d8b   About a minute ago   Running             etcd                                          0                   19b10671d35c0
    5827c99240362       d1eec47fd97e5adda38c64780292df9c2eae0f260c0c26ed501822fbd2eb6d8b   About a minute ago   Running             etcdctl                                       0                   19b10671d35c0
    [root@master01 manifests]# crictl inspect ed5bedcf1715a |grep pid    "pid": 2659729,          "pids": {
    	    "type": "pid"
    [root@master01 manifests]# ETCDCTL_API=3 nsenter -n -p -m -t 2659729 -- etcdctl endpoint status --write-out=table --endpoints=https://10.0.0.182:2379 --cert=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.crt --key=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.key --cacert=/etc/kubernetes/static-pod-certs/configmaps/etcd-serving-ca/ca-bundle.crt
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    |        ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    | https://10.0.0.182:2379 | 6d0ac07810a4b7be |   3.4.9 |   78 MB |      true |      false |         3 |       6890 |               6890 |        |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    [root@master01 manifests]# ETCDCTL_API=3 nsenter -n -p -m -t 2659729 -- etcdctl member list --write-out=table --endpoints=https://10.0.0.182:2379 --cert=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.crt --key=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.key --cacert=/etc/kubernetes/static-pod-certs/configmaps/etcd-serving-ca/ca-bundle.crt+------------------+---------+----------+-------------------------+-------------------------+------------+
    |        ID        | STATUS  |   NAME   |       PEER ADDRS        |      CLIENT ADDRS       | IS LEARNER |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    | 6d0ac07810a4b7be | started | master01 | https://10.0.0.182:2380 | https://10.0.0.182:2379 |      false |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    [root@master01 manifests]#

so a single etcd is still up and running ok. i think the hanging is caused by a rollout of a new kube-apiserver, because i deleted master02/03. we only have on master now&#x2026;

some clusteroperators are progessing (kube-apiserver)

    [root@bastion ~]# oc get clusteroperator
    NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
    authentication                             4.5.7     True        False         True       5d21h
    cloud-credential                           4.5.7     True        False         False      5d23h
    cluster-autoscaler                         4.5.7     True        False         False      5d22h
    config-operator                            4.5.7     True        False         False      5d22h
    console                                    4.5.7     True        False         False      7m13s
    csi-snapshot-controller                    4.5.7     True        True          False      4d7h
    dns                                        4.5.7     True        False         False      5d22h
    etcd                                       4.5.7     True        False         True       5d22h
    image-registry                             4.5.7     True        False         True       5d22h
    ingress                                    4.5.7     True        False         False      24h
    insights                                   4.5.7     True        False         False      5d22h
    kube-apiserver                             4.5.7     True        True          False      5d22h
    kube-controller-manager                    4.5.7     True        False         False      5d22h
    kube-scheduler                             4.5.7     True        True          False      5d22h
    kube-storage-version-migrator              4.5.7     True        False         False      17h
    machine-api                                4.5.7     True        False         False      5d22h
    machine-approver                           4.5.7     True        False         False      5d22h
    machine-config                             4.5.7     True        False         False      16h
    marketplace                                4.5.7     True        False         False      24h
    monitoring                                 4.5.7     False       True          True       6m16s
    network                                    4.5.7     True        False         False      5d22h
    node-tuning                                4.5.7     True        False         False      4d12h
    openshift-apiserver                        4.5.7     False       False         False      2m1s
    openshift-controller-manager               4.5.7     True        False         False      5d19h
    openshift-samples                          4.5.7     True        False         False      4d12h
    operator-lifecycle-manager                 4.5.7     True        False         False      5d22h
    operator-lifecycle-manager-catalog         4.5.7     True        False         False      5d22h
    operator-lifecycle-manager-packageserver   4.5.7     True        False         False      24h
    service-ca                                 4.5.7     True        False         False      5d22h
    storage                                    4.5.7     True        False         False      4d12h
    [root@bastion ~]#

reinstalled master02 and master03

oc command started hanging again, IMHO kubeapiserver is restarting,
seems to be a loop, doesn't work with on kubeapiserver running.  but
cluster seems to be ok otherwise.

master02 and master03 installed fine, waiting for CSR's to
arrive. this takes some time here because they are pulling a 1gb image
and my connection is <span class="underline">slow</span>.

    [core@master02 ~]$ ps ax |grep "[p]odman pull"
       1714 ?        Sl     0:21 podman pull -q --authfile /var/lib/kubelet/config.json quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:7dc3cff1ca67fa2c2364d84a0dc0b2d2aa518da903eacac4ad9a56a4841e0553
    [core@master02 ~]$

after a few minutes csr's arrive

    [root@bastion ~]# oc get csr
    NAME        AGE   SIGNERNAME                                    REQUESTOR                                                                   CONDITION
    csr-8hwl7   17h   kubernetes.io/kubelet-serving                 system:node:master03                                                        Approved,Issued
    csr-b2fpm   3s    kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Pending
    csr-fdbmv   17h   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Approved,Issued
    csr-tc9b5   52s   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Pending
    [root@bastion ~]# oc adm certificate approve csr-b2fpm csr-tc9b5
    certificatesigningrequest.certificates.k8s.io/csr-b2fpm approved
    certificatesigningrequest.certificates.k8s.io/csr-tc9b5 approved

    [root@bastion ~]# oc get csr
    NAME        AGE   SIGNERNAME                                    REQUESTOR                                                                   CONDITION
    csr-8hwl7   17h   kubernetes.io/kubelet-serving                 system:node:master03                                                        Approved,Issued
    csr-b2fpm   48s   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Approved,Issued
    csr-fdbmv   17h   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Approved,Issued
    csr-fz66b   22s   kubernetes.io/kubelet-serving                 system:node:master02                                                        Pending
    csr-tc9b5   97s   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Approved,Issued
    csr-tz2x5   22s   kubernetes.io/kubelet-serving                 system:node:master03                                                        Pending
    [root@bastion ~]# ^Censhift-install --dir=/root/ocp/install wait-for bootstrap-complete
    [root@bastion ~]# ^C
    [root@bastion ~]# oc adm certificate approve csr-fz66b csr-tz2x5
    certificatesigningrequest.certificates.k8s.io/csr-fz66b approved
    certificatesigningrequest.certificates.k8s.io/csr-tz2x5 approved
    [root@bastion ~]#

new master02 and 03 are in the "not ready" state

    [root@bastion ~]# oc get nodes
    NAME       STATUS     ROLES    AGE     VERSION
    infra01    Ready      worker   5d22h   v1.18.3+2cf11e2
    infra02    Ready      worker   5d21h   v1.18.3+2cf11e2
    master01   Ready      master   5d23h   v1.18.3+2cf11e2
    master02   NotReady   master   63s     v1.18.3+2cf11e2
    master03   NotReady   master   63s     v1.18.3+2cf11e2
    worker01   Ready      worker   5d21h   v1.18.3+2cf11e2
    worker02   Ready      worker   5d22h   v1.18.3+2cf11e2

etcd member list still show's only one member

    [root@master01 manifests]# ETCDCTL_API=3 nsenter -n -p -m -t 2659729 -- etcdctl member list --write-out=table --endpoints=https://10.0.0.182:2379,https://10.0.0.183:2379,https://10.0.0.184:2379 --cert=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.crt --key=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.key --cacert=/etc/kubernetes/static-pod-certs/configmaps/etcd-serving-ca/ca-bundle.crt
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |        ID        | STATUS  |   NAME   |       PEER ADDRS        |      CLIENT ADDRS       | IS LEARNER |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    | 6d0ac07810a4b7be | started | master01 | https://10.0.0.182:2380 | https://10.0.0.182:2379 |      false |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    [root@master01 manifests]#

after 5-10 minutes etcd pod got restarted and seemd to running in a 3 node cluster again

    [root@master01 manifests]# crictl ps |grep etcde5c3511cea9fd       d1eec47fd97e5adda38c64780292df9c2eae0f260c0c26ed501822fbd2eb6d8b   About a minute ago   Running             etcd-metrics                                  0                   cf92570a2aa098378b34b47be3       d1eec47fd97e5adda38c64780292df9c2eae0f260c0c26ed501822fbd2eb6d8b   About a minute ago   Running             etcd                                          0                   cf92570a2aa09
    fc1d0dff8cc2c       d1eec47fd97e5adda38c64780292df9c2eae0f260c0c26ed501822fbd2eb6d8b   About a minute ago   Running             etcdctl                                       0                   cf92570a2aa09
    [root@master01 manifests]# crictl inspect 8378b34b47be3 |grep pid    "pid": 2715094,          "pids": {
    	    "type": "pid"
    [root@master01 manifests]# ETCDCTL_API=3 nsenter -n -p -m -t 2715094 -- etcdctl member list --write-out=table --endpoints=https://10.0.0.182:2379,https://10.0.0.183:2379,https://10.0.0.184:2379 --cert=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.crt --key=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.key --cacert=/etc/kubernetes/static-pod-certs/configmaps/etcd-serving-ca/ca-bundle.crt
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    |        ID        | STATUS  |   NAME   |       PEER ADDRS        |      CLIENT ADDRS       | IS LEARNER |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    | 56332250359fcab5 | started | master03 | https://10.0.0.184:2380 | https://10.0.0.184:2379 |      false |
    | 6936066826348094 | started | master02 | https://10.0.0.183:2380 | https://10.0.0.183:2379 |      false |
    | 6d0ac07810a4b7be | started | master01 | https://10.0.0.182:2380 | https://10.0.0.182:2379 |      false |
    +------------------+---------+----------+-------------------------+-------------------------+------------+
    [root@master01 manifests]# ETCDCTL_API=3 nsenter -n -p -m -t 2715094 -- etcdctl endpoint status --write-out=table --endpoints=https://10.0.0.182:2379,https://10.0.0.183:2379,https://10.0.0.184:2379 --cert=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.crt --key=/etc/kubernetes/static-pod-certs/secrets/etcd-all-serving/etcd-serving-master01.key --cacert=/etc/kubernetes/static-pod-certs/configmaps/etcd-serving-ca/ca-bundle.crt
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    |        ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    | https://10.0.0.182:2379 | 6d0ac07810a4b7be |   3.4.9 |   78 MB |     false |      false |         4 |      18265 |              18265 |        |
    | https://10.0.0.183:2379 | 6936066826348094 |   3.4.9 |   78 MB |      true |      false |         4 |      18265 |              18265 |        |
    | https://10.0.0.184:2379 | 56332250359fcab5 |   3.4.9 |   78 MB |     false |      false |         4 |      18265 |              18265 |        |
    +-------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
    [root@master01 manifests]#

kube-apiserver is progressing

    [root@bastion ~]# oc get clusteroperator
    NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
    authentication                             4.5.7     True        False         False      5d21h
    cloud-credential                           4.5.7     True        False         False      5d23h
    cluster-autoscaler                         4.5.7     True        False         False      5d22h
    config-operator                            4.5.7     True        False         False      5d23h
    console                                    4.5.7     True        False         False      31m
    csi-snapshot-controller                    4.5.7     True        True          False      4d7h
    dns                                        4.5.7     True        False         False      5d23h
    etcd                                       4.5.7     True        False         False      5d23h
    image-registry                             4.5.7     True        False         True       5d23h
    ingress                                    4.5.7     True        False         False      24h
    insights                                   4.5.7     True        False         False      5d23h
    kube-apiserver                             4.5.7     True        True          False      5d23h
    kube-controller-manager                    4.5.7     True        False         False      5d23h
    kube-scheduler                             4.5.7     True        False         False      5d23h
    kube-storage-version-migrator              4.5.7     True        False         False      17h
    machine-api                                4.5.7     True        False         False      5d23h
    machine-approver                           4.5.7     True        False         False      5d23h
    machine-config                             4.5.7     True        False         False      17h
    marketplace                                4.5.7     True        False         False      24h
    monitoring                                 4.5.7     False       True          True       20m
    network                                    4.5.7     True        False         False      5d23h
    node-tuning                                4.5.7     True        False         False      4d12h
    openshift-apiserver                        4.5.7     True        False         False      23m
    openshift-controller-manager               4.5.7     True        False         False      5d19h
    openshift-samples                          4.5.7     True        False         False      4d12h
    operator-lifecycle-manager                 4.5.7     True        False         False      5d23h
    operator-lifecycle-manager-catalog         4.5.7     True        False         False      5d23h
    operator-lifecycle-manager-packageserver   4.5.7     True        False         False      20m
    service-ca                                 4.5.7     True        False         False      5d23h
    storage                                    4.5.7     True        False         False      4d12h

nodes are ready

    [root@bastion ~]# oc get nodes
    NAME       STATUS   ROLES    AGE     VERSION
    infra01    Ready    worker   5d22h   v1.18.3+2cf11e2
    infra02    Ready    worker   5d22h   v1.18.3+2cf11e2
    master01   Ready    master   5d23h   v1.18.3+2cf11e2
    master02   Ready    master   14m     v1.18.3+2cf11e2
    master03   Ready    master   14m     v1.18.3+2cf11e2
    worker01   Ready    worker   5d22h   v1.18.3+2cf11e2
    worker02   Ready    worker   5d22h   v1.18.3+2cf11e2
