
# Table of Contents

1.  [Destroying a host](#orgc45c58a)
    1.  [Destroy a libvirt guest on the local playground](#org2ba0cf0)
    2.  [Destroy a libvirt guest on a remote playground host](#orgf17dd6f)


<a id="orgc45c58a"></a>

# Destroying a host


<a id="org2ba0cf0"></a>

## Destroy a libvirt guest on the local playground

    ansible-playbook playbooks/destroy_host -e guest=theguest


<a id="orgf17dd6f"></a>

## Destroy a libvirt guest on a remote playground host

    ansible-playbook playbooks/destroy_host -e host=playground.host -e guest=theguest
