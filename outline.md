# (Ab)using Docker for automated testing of Ansible roles on multiple distros with Travis-CI

## Premise/motivation

- I develop roles (originally, only for latest CentOS) and want them tested
- Original setup: Vagrant environment, boot box, apply role
- Add more platforms => setup becomes tedious:
    - Vagrantfile complexity
    - Launching tests takes time, distracts
    - Can't run in parallel

I want to automate all the things!

- Online Continuous Integration/Delivery tool?
    - start VM, apply role, run tests
- My roles: CentOS, most tools: Ubuntu
- Then I found out that Travis-CI supports Docker

## Iteration 1: testing roles for CentOS

- Create Docker container image with:
    - systemd
    - Ansible installed & configured
- `.travis.yml`:
    - pull image
    - start container
    - run `ansible-playbook` inside the container, locally

## Iteration 2: multi-platform tests

- Docker container images for Ubuntu 12.04, 14.04
- `.travis.yml`: environment matrix to
- PoC  `geerlingguy.apache` and submitted as [PR#60](https://github.com/geerlingguy/ansible-role-apache/pull/60)

## Iteration 3: scripted

- `.travis.yml` contained all commands, not reusable
- Moved to `docker-tests.sh`
- Added `acceptance-tests.sh`, to be run from the host system (= Travis-CI VM, or dev laptop)
    - Is the service available from outside?
    - Uses BATS
- => Run Docker tests locally before pushing to Git & triggering Travis-CI builds

## Limits, issues

There's always something...

- systemd needs to run inside container: not the intended use case
- SELinux on host system has impact on what works (or not) inside the container
- `docker-tests` script hangs in CentOS 6 image, *after* finishing running playbooks
- Depending on distro/version, other options needed for Docker run
    - Am I doing it wrong?

## Future work

- Use Ansible Container
    - Use official distro images instead of maintaining my own images
- Apply to all my roles

## Thank you!

Feedback/cooperation welcome!

See
- <https://github.com/bertvv/ansible-toolbox>
- <https://github.com/bertvv/ansible-role-skeleton>

