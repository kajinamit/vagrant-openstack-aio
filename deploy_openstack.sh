#!/bin/bash
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

pushd /vagrant

if [ -f vars ]; then
  source ./vars
fi

RELEASE=${RELEASE:-master}
case ${RELEASE} in
  "antelope")
     BRANCH='stable/2023.1'
     ;;
  "bobcat")
     BRANCH='stable/2023.2'
     ;;
  "caracal")
     BRANCH='stable/2024.1'
     ;;
  "master")
     BRANCH=$RELEASE
     ;;
  *)
     BRANCH="stable/${RELEASE}"
     ;;
esac

if [ -f ./manifest.pp ]; then
  MANIFEST=./manifest.pp
else
  MANIFEST=/usr/share/openstack-puppet/modules/openstack_integration/fixtures/scenario-aio.pp
fi

dnf clean all
dnf config-manager --enable crb
dnf update -y
dnf install -y vim wget git
wget -P /etc/yum.repos.d/ https://trunk.rdoproject.org/centos9-$RELEASE/puppet-passed-ci/delorean.repo
wget -P /etc/yum.repos.d/ https://trunk.rdoproject.org/centos9-$RELEASE/delorean-deps.repo

dnf install -y 'puppet-*'
git clone -b $BRANCH https://github.com/openstack/puppet-openstack-integration.git /usr/share/openstack-puppet/modules/openstack_integration

mkdir -p /tmp/openstack/image
wget https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img -P /tmp/openstack/image
mv /tmp/openstack/image/cirros-0.6.2-x86_64-disk.img /tmp/openstack/image/cirros-0.6.2-x86_64-disk-qcow2.img

puppet apply --modulepath /usr/share/openstack-puppet/modules $MANIFEST | tee -a /var/log/puppet.log

mkdir /home/vagrant/.config
mkdir -m 700 /home/vagrant/.config/openstack
cp --preserve=mode /vagrant/clouds.yaml /home/vagrant/.config/openstack
chown -R vagrant:vagrant /home/vagrant/.config

popd
