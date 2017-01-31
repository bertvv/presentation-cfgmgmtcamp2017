% (Ab)using Docker for automated testing of Ansible roles on multiple distros with Travis-CI
% Bert Van Vreckem
% Config Management Camp 2017 Ghent, 2017-02-06

# Intro

## `whoami`

- Bert Van Vreckem
- *Lector ICT* at University College Ghent (HoGent)
    - BS programme Applied Informatics
    - Mainly Linux, research techniques
- *Open source* contributor: <https://github.com/bertvv/>
    - Ansible roles
    - Scripts
    - Course material
    - ...

## Agenda

TODO

# Motivation

## Motivation

- I develop roles <https://galaxy.ansible.com/bertvv/>
    - ~16 on Ansible Galaxy, some more unreleased
    - Primary target platform = latest *CentOS*
- *Testing* matters to me
- *Automate* all the things!

## Let's create an "ftp" role

- Initial target platforms:
    1. CentOS 7
    2. Ubuntu 14.04
- Bootstrapping automated with <https://github.com/bertvv/ansible-toolbox>

# Original setup

## Role scaffolding code

<https://github.com/bertvv/ansible-role-skeleton>

```
$ atb role --tests=vagrant ftp
$ tree ftp/
ftp/
├── CHANGELOG.md
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
├── LICENSE.md
├── meta/
│   └── main.yml
├── README.md
├── tasks/
│   └── main.yml
├── vagrant-tests/  # see below
└── vars/
    └── RedHat.yml

5 directories, 8 files
```

## Test code

- on a separate branch
- included through `git-worktree`

```
$ tree vagrant-tests/
vagrant-tests/
├── README.md
├── roles
│   └── ftp -> ../..
├── test.yml
└── Vagrantfile

2 directories, 3 files
```

## Vagrantfile

```Ruby
require 'rbconfig'

ROLE_NAME = 'ftp'
HOST_NAME = 'test' + ROLE_NAME
VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = 'bertvv/centos72'

  config.vm.define HOST_NAME do |node|
    node.vm.hostname = HOST_NAME
    node.vm.network :private_network, ip: '192.168.56.42'
    node.vm.provision 'ansible' do |ansible|
      ansible.playbook = 'test.yml'
    end
  end
end
```

## test.yml

```Yaml
---
- hosts: all
  become: true
  roles:
    - ftp
```

## Running tests

```
$ vagrant up
Bringing machine 'testftp' up with 'virtualbox' provider...
==> testftp: Importing base box 'bertvv/centos72'...
[...]
==> testftp: Running provisioner: ansible...
    testftp: Running ansible-playbook...

PLAY [all] *********************************************************************

TASK [setup] *******************************************************************
ok: [testftp]

TASK [ftp : include_vars] ******************************************************
ok: [testftp] => (item=/home/bert/Downloads/ftp/vars/RedHat.yml)

TASK [ftp : Install packages] **************************************************
changed: [testftp] => (item=[u'vsftpd'])

TASK [ftp : Ensure service is started] *****************************************
changed: [testftp]

PLAY RECAP *********************************************************************
testftp                    : ok=4    changed=2    unreachable=0    failed=0
```

## Issues

This served me fine, but...

Supporting multiple platforms is hard

- Vagrantfile complexity
- Running tests distracts
- Can't run in parallel

## CI

=> search for a CI/CD tool

- My roles: CentOS / most tools: Ubuntu
- Then I found uit Travis-CI supports docker...

# Iteration 1: testing roles for CentOS

## Setup

- Docker image with
    - `systemd`
    - Ansible + dependencies installed
        - configured to run locally
- `.travis.yml`:
    - pulls image
    - start container
    - run `ansible-playbook test.yml` inside the container

---

<https://hub.docker.com/r/bertvv/ansible-testing/>

```Dockerfile
FROM centos:7
MAINTAINER Bert Van Vreckem <bert.vanvreckem@gmail.com>
ENV container docker

# Install systemd -- See https://hub.docker.com/_/centos/
RUN \
    (cd /lib/systemd/system/sysinit.target.wants/ || exit; for i in *; do [ "$i" = systemd-tmpfiles-setup.service ] || rm -f "$i"; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*; \
    rm -f /etc/systemd/system/*.wants/*; \
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*; \
    rm -f /lib/systemd/system/anaconda.target.wants/*; \
# Continued
```

---

```Dockerfile
    yum -y upgrade; \
    yum -y install epel-release; \
    yum -y install git ansible sudo libselinux-python iproute; \
    yum clean all; \
    sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/'  /etc/sudoers; \
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts; \
    echo -e '[defaults]\nretry_files_enabled = False' > /etc/ansible/ansible.cfg


VOLUME ["/sys/fs/cgroup"]
CMD ["/usr/sbin/init"]
```


