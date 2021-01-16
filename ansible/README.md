
# Table of Contents

1.  [Destroying a host](#org1000e40)
    1.  [Destroy a libvirt guest on the local playground](#org144d814)
    2.  [Destroy a libvirt guest on a remote playground host](#orgb329382)


<a id="org1000e40"></a>

# Destroying a host


<a id="org144d814"></a>

## Destroy a libvirt guest on the local playground

    ansible-playbook playbooks/destroy_host -e guest=theguest


<a id="orgb329382"></a>

## Destroy a libvirt guest on a remote playground host

    ansible-playbook playbooks/destroy_host -e host=playground.host -e guest=theguest
