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

- Testing with Vagrant
- Iteration 1: testing roles for CentOS
- Iteration 2: add platforms
- Iteration 3: refactoring, functional tests
- Discussion, future work

Presentation: <https://bertvv.github.io/presentation-cfgmgmtcamp2017/>

## Motivation

- I develop roles <https://galaxy.ansible.com/bertvv/>
    - ~16 on Ansible Galaxy, some more unreleased
    - Primary target platform = latest *CentOS*
- *Testing* matters to me
- *Automate* all the things!

## Let's create an "ftp" role

- Initial target platform: CentOS 7
- Add Vagrant & Docker tests
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

- on a separate orphan branch
- "mounted" through `git-worktree`

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

Test playbook:

```Yaml
# Test playbook for Ansible role bertvv.ftp
---
- hosts: all
  become: true
  roles:
    - role_under_test
  post_tasks:
    - name: Put a file into the shared directory
      copy:
        dest: /var/ftp/pub/README
        content: 'hello world!'
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

[...]

TASK [ftp : Ensure service is started] *****************************************
changed: [testftp]

PLAY RECAP *********************************************************************
testftp                    : ok=4    changed=2    unreachable=0    failed=0
```

Afterwards: `curl ftp://192.168.56.42/pub/README`

## Issues

This still serves me fine, but...

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

---

```Yaml
# .travis.yml
---
sudo: required
env:
  - CONTAINER_ID=$(mktemp)

services:
  - docker

before_install:
  - sudo apt-get update
  - sudo docker pull bertvv/ansible-testing:centos_7

script:
  - sudo docker run --detach --privileged \
      --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro \
      --volume="${PWD}":/etc/ansible/roles/role_under_test:ro \
      bertvv/ansible-testing:centos_7 /usr/sbin/init > "${CONTAINER_ID}"
  - sudo docker exec "$(cat ${CONTAINER_ID})" \
      ansible-playbook /etc/ansible/test.yml --syntax-check
  - sudo docker exec "$(cat ${CONTAINER_ID})" \
      ansible-playbook /etc/ansible/test.yml
```

# Iteration 2: add platforms

## Setup

- If we can do this for one distro, why not for others?
- Added container images for Ubuntu 12.04, 14.04, CentOS 6
- `.travis.yml` with environment matrix
- Built PoC based on [`geerlingguy.apache`](https://galaxy.ansible.com/geerlingguy/apache/)
    - submitted  [PR#60](https://github.com/geerlingguy/ansible-role-apache/pull/60), was [accepted](https://github.com/geerlingguy/ansible-role-apache/pull/60#issuecomment-164291402)

---

```Yaml
# .travis.yml
sudo: required
env:
  - distribution: centos
    version: 6
    init: /sbin/init
    run_opts: ""
    container_id: $(mktemp)
  - distribution: centos
    version: 7
    init: /usr/lib/systemd/systemd
    run_opts: "--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    container_id: $(mktemp)
  - distribution: ubuntu
    version: 14.04
    init: /sbin/init
    run_opts: ""
    container_id: $(mktemp)
  - distribution: ubuntu
    version: 12.04
    init: /sbin/init
    run_opts: ""
    container_id: $(mktemp)
```

---

```Yaml
services:
  - docker

before_install:
  - sudo apt-get update
  # Pull container
  - sudo docker pull bertvv/ansible-testing:${distribution}_${version}
```

---

```Yaml
script:
  # Run container in detached state
  - sudo docker run --detach \
      --volume="${PWD}":/etc/ansible/roles/role_under_test:ro \
      ${run_opts} bertvv/ansible-testing:${distribution}_${version} \
      "${init}" > "${container_id}"

  # Syntax check
  - sudo docker exec --tty "$(cat ${container_id})" env TERM=xterm \
      ansible-playbook /etc/ansible/roles/role_under_test/tests/test.yml \
      --syntax-check
  # Test role
  - sudo docker exec --tty "$(cat ${container_id})" env TERM=xterm \
      ansible-playbook /etc/ansible/roles/role_under_test/tests/test.yml \
  # Idempotence test
  - >
    sudo docker exec "$(cat ${container_id})"  env TERM=xterm
      ansible-playbook /etc/ansible/roles/role_under_test/tests/test.yml
      | grep -q 'changed=0.*failed=0'
    && (echo 'Idempotence test: pass' && exit 0)
    || (echo 'Idempotence test: fail' && exit 1)
```

# Iteration 3: Refactoring, functional tests

## Setup

- It#2: All commands enumerated in `.travis.yml`
    - Limited reusability
    - Hard to reproduce locally
- Moved code to `docker-tests.sh`
- Added framework for functional tests

---

```Yaml
# .travis.yml Execution script for role tests on Travis-CI
---
sudo: required

env:
  matrix:
    - DISTRIBUTION: centos
      VERSION: 7
    - DISTRIBUTION: ubuntu
      VERSION: 14.04
    - DISTRIBUTION: ubuntu
      VERSION: 16.04

services:
  - docker

before_install:
    # Install latest Git
  - sudo apt-get update
  - sudo apt-get install --only-upgrade git
    # Allow fetching other branches than master
  - git config remote.origin.fetch +refs/heads/*:refs/remotes/origin/*
    # Fetch the branch with test code
  - git fetch origin docker-tests
  - git worktree add docker-tests origin/docker-tests
```

---

```Yaml
script:
  # Create container and apply test playbook
  - ./docker-tests/docker-tests.sh

  # Run functional tests on the container
  - SUT_IP=172.17.0.2 ./docker-tests/functional-tests.sh
```

## `docker-tests.sh`

To run locally:

`DISTRIBUTION=centos VERSION=7 docker-tests/docker-tests.sh`

```Bash
main() {
  # Sets distribution-specific run-options for docker
  configure_environment

  start_container

  run_syntax_check
  run_test_playbook
  run_idempotence_test

  # cleanup
}
```

---

```Bash
start_container() {
  log "Starting container"
  set -x
  docker run --detach \
    --volume="${PWD}:${role_dir}:ro" \
    "${run_opts[@]}" \
    "${docker_image}:${DISTRIBUTION}_${VERSION}" \
    "${init}" \
    > "${container_id}"
  set +x
}
```

---

```Bash
run_syntax_check() {
  log 'Running syntax check on playbook'
  exec_container ansible-playbook "${test_playbook}" --syntax-check
  log 'Syntax check finished'
}

run_test_playbook() {
  log 'Running playbook'
  exec_container ansible-playbook "${test_playbook}"
  log 'Run finished'
}
```

---

```Bash
exec_container() {
  local id
  id="$(get_container_id)"

  set -x
  docker exec --tty \
    "${id}" \
    env TERM=xterm \
    "${@}"
  set +x
}
```

---

```Bash
run_idempotence_test() {
  log 'Running idempotence test'
  local output
  output="$(mktemp)"

  exec_container ansible-playbook "${test_playbook}" 2>&1 | tee "${output}"

  if grep -q 'changed=0.*failed=0' "${output}"; then
    result='pass'
    return_status=0
  else
    result='fail'
    return_status=1
  fi
  rm "${output}"

  log "Result: ${result}"
  return "${return_status}"
}
```

## `functional-tests.sh`

- Installs [Bash Automated Testing Framework](https://github.com/sstephenson/bats)
- Looks for `.bats` files and runs them

---

Example: `ftp.bats`

```Bash
#! /usr/bin/env bats
#
# Variable SUT_IP should be set outside the script and should contain
# the IP address of the System Under Test.

@test 'Anonymous user should be able to fetch README' {
  run curl --silent "ftp://${SUT_IP}/pub/README"

  echo "Result: ${output}"

  [ "${status}" -eq "0" ]
  [ "${output}" = "hello world!" ]
}
```

## Running the tests

```
$ DISTRIBUTION=centos VERSION=7 ./docker-tests/docker-tests.sh
>>> Starting container
[...]
>>> Running syntax check on playbook
[...]
>>> Syntax check finished
>>> Running playbook
[...]
>>> Run finished
>>> Running idempotence test
[...]
>>> Result: pass

```

---

```
$ SUT_IP=172.17.0.2 ./docker-tests/functional-tests.sh
### Using BATS executable at: /usr/local/bin/bats
### Running test /home/bert/Downloads/ftp/docker-tests/ftp.bats
 ✓ Anonymous user should be able to fetch README

1 test, 0 failures

```

# Recap

## Role + tests setup

```
$ atb role --tests=docker ftp
$ cd ftp
$ vi tasks/main.yml
[ write your role... ]
$ vi docker-tests/test.yml
[...]
$ vi docker-tests/ftp.bats
[...]
$ DISTRIBUTION=centos VERSION=7 ./docker-tests/docker-tests.sh
$ SUT_IP=172.17.0.2 ./docker-tests/functional-tests.sh
```

Does this work? Ship it!

## Examples

- Role [bertvv.vsftpd]()
    - Github: <https://github.com/bertvv/ansible-role-vsftpd>
    - Travis-CI: <https://travis-ci.org/bertvv/ansible-role-vsftpd>
- Role [bertvv.bind](https://galaxy.ansible.com/bertvv/bind/)
    - Github: <https://github.com/bertvv/ansible-role-bind>
    - Travis-CI: <https://travis-ci.org/bertvv/ansible-role-bind>

# Discussion

## Limits, issues

There's always something...

- Not intended use case for Docker
- Impact of *SELinux*
    - Laptop = Fedora vs Travis-CI = Ubuntu
    - SELinux settings aren't tested on Travis-CI!
    - SELinux on host breaks stuff inside

---

- Different *run options* depending on distro/version
    - trial&error, am I doing it wrong?
- `docker-tests.sh` hangs on CentOS 6 image
    - after succesfully finishing playbook

## Future work

- Use Ansible Container
    - official distro images instead of my own
- (Try to) fix issues
- Apply to all my roles

# That's it!

## Thank you!

Feedback welcome!

- Twitter: [bertvanvreckem](https://twitter.com/bertvanvreckem)
- Github: <https://github.com/bertvv>
- Galaxy: <https://galaxy.ansible.com/bertvv/>

## Read more

- Blog post "Testing Ansible Roles With Travis-CI"
    - [Part 1: CentOS](https://bertvv.github.io/notes-to-self/2015/12/11/testing-ansible-roles-with-travis-ci-part-1-centos)
    - [Part 2: Multi-platform tests](https://bertvv.github.io/notes-to-self/2015/12/13/testing-ansible-roles-with-travis-ci-part-2-multi-platform-tests)
- Jeff Geerling, [Ansible for DevOps](https://www.ansiblefordevops.com/), Chapter 11
