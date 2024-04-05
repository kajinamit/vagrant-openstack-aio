Vagrantfile for All-in-One OpenStack
====================================

This aimds to provide an easy way to build a single-node
[OpenStack](https://www.openstack.org/) deployment.

The deployment uses CentOS 9 Stream + [RDO](https://www.rdoproject.org/) master
so that users can evaluate the latest features under development. Deployment
has the following services enabled.

* Middleware
  * Apache Web Server
  * MariaDB
  * Memcached
  * RabbitMQ
* OpenStack components
  * Keystone
  * Nova
  * Placement
  * Cinder (with lvm backend)
  * Glance (with file image store)
  * Neutron (with ml2-ovs plugin)
  * Horizon
  * Tempest

The deployment process internally uses puppet. See
[Puppet OpenStack guide](https://docs.openstack.org/puppet-openstack-guide/latest/)
to find details about puppet modules to deploy OpenStack.

Prerequisites
-------------
* Vagrant with libvirt provider

* CentOS 9 Stream box downloaded from
  [CentOS mirror](https://cloud.centos.org/centos/9-stream/x86_64/images/)

* Reserve 4 vCPU + 8 GiB memory + 10 GiB Disk for the VM

> [!NOTE]
> Other provides such as virtualbox provider may work but may need some
> adjustments

> [!NOTE]
> Currently the official CentOS 9 Stream box in
> [Vagrant Cloud](https://app.vagrantup.com/centos/boxes/stream9) is outdated.
> Download the box file from the CentOS mirror instead.

How to use
----------

1. Provision the OpenStack VM

  ```
  $ vagrant up
  ```

2. Once the provisioning process completes, login to the VM

  ```
  $ vagrant ssh
  ```

4. Use OpenStack CLI with admin user credential 

  ```
  $ export OS_CLOUD=admin
  $ openstack user list
  +----------------------------------+-----------+
  | ID                               | Name      |
  +----------------------------------+-----------+
  | 7b351154e9644f35bd051d66ec19eddd | admin     |
  | b3d8490632f444efb130aa6064c9148f | demo      |
  | e594aab1b2774f37a25f09a5895026b7 | glance    |
  | 58ab903f5935431a9798eae42f2b0777 | neutron   |
  | 56ca4b958f974fb693de3eb32e155035 | placement |
  | e0d3c3f56b1a47c7aeac07dd1a5e545d | nova      |
  | 033d09306bc8463c825317259b15b51e | cinder    |
  +----------------------------------+-----------+
  ```

5. You can also use the ``demo`` user with member role

  ```
  $ export OS_CLOUD=demo
  $ openstack server list
  ```

6. [CirrOS](https://github.com/cirros-dev/cirros) image, small flavors and
   `public` neutron network are prepared during the deployment process

  ```
  $ export OS_CLOUD=demo
  $ openstack image list
  +--------------------------------------+------------+--------+
  | ID                                   | Name       | Status |
  +--------------------------------------+------------+--------+
  | d800c329-3b7d-4ec6-8aa3-40a59d26f3d7 | cirros     | active |
  | d349255c-f5cc-4769-9c88-ad5f3d672181 | cirros_alt | active |
  +--------------------------------------+------------+--------+
  $ openstack flavor list
  +----+----------+-----+------+-----------+-------+-----------+
  | ID | Name     | RAM | Disk | Ephemeral | VCPUs | Is Public |
  +----+----------+-----+------+-----------+-------+-----------+
  | 42 | m1.nano  | 128 |    2 |         0 |     1 | True      |
  | 84 | m1.micro | 128 |    2 |         0 |     1 | True      |
  +----+----------+-----+------+-----------+-------+-----------+
  $ openstack network list
  +--------------------------------------+--------+--------------------------------------+
  | ID                                   | Name   | Subnets                              |
  +--------------------------------------+--------+--------------------------------------+
  | 15a1a72d-b3c1-40ce-a67a-abb640438951 | public | c0a287e2-a626-4e7c-9309-ffec0186b41a |
  +--------------------------------------+--------+--------------------------------------+
  ```

7. Create a private network, router, and security group to allow ssh access

  ```
  $ export OS_CLOUD=demo
  $ openstack network create private
  $ openstack subnet create private-subnet --network private \
      --subnet-range 192.168.10.0/24
  $ openstack router create demorouter --external-gateway public
  $ openstack router add subnet demorouter private-subnet
  $ openstack security group create ssh
  $ openstack security group rule create ssh \
      --protocol tcp --dst-port 22:22 --remote-ip 0.0.0.0/0
  ```

8. Then an instance can be created, being connected to the private network

  ```
  $ openstack server create \
      --network private --security-group ssh \
      --flavor m1.nano --image cirros \
      demoinstance
  ```

9. Create a floating ip and assign it to the server

  ```
  $ openstack floating ip create public
  $ openstack server add floating ip demoinstance FLOATING_IP
  ```

> [!NOTE]
> Replace `FLOATING_IP` by the actual floating IP address.

10. Connect to the instance by ssh

   ```
   $ openstack server ssh demoinstance -- -l cirros
   cirros@<IP>'s password: <-- Enter 'gocubsgo'
   ```

Known issues
------------
* The loopback device used by cinder is not persistent and need manual steps
  when the VM is rebooted.

  ```
  $ sudo losetup /dev/loop2 /var/lib/cinder/cinder-volumes
  $ sudo udevadm settle
  $ sudo systemctl restart openstack-cinder-volume
  ```

* The deployed services by default accept only localhost access and are not
  accessible from external servers. To allow external access to Dashboard
  (Horizon), edit the ALLOED_HOSTS and restart the httpd service.
  Note that further adjustments may be needed to make instance console
  accessible from external servers.

  ```
  $ sudo vim /etc/openstack-dashboard/local_settings
  ...
  ALLOWED_HOSTS = ['*',]
  ...
  $ sudo systemctl restart httpd
  ```

* While the `public` neutron network can be reached from/to the hypervisor, it
  is not connected to external networks to which the hypervisor connect. To
  provide full external network access, you may need to configure NAT in the VM
  or connect the `br-ex` bridge to any network interface of the VM.

* The yum repository file is not updated automatically and you may need to
  fetch the latest
  [delorean.repo](https://trunk.rdoproject.org/centos9-master/puppet-passed-ci/delorean.repo)
  and
  [delorean-deps.repo](https://trunk.rdoproject.org/centos9-master/delorean-deps.repo)
  to update packages.
