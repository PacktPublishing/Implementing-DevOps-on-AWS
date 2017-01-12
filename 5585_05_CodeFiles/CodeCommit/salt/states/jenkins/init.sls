include:
  - docker
  - nginx

jenkins_prereq:
  pkg.installed:
    - pkgs:
      - java-1.7.0-openjdk
      - gcc
      - make
      - createrepo
      - jq
      - httpd-tools

jenkins:
  pkg.installed:
    - sources:
      - jenkins: http://mirrors.jenkins-ci.org/redhat-stable/jenkins-2.7.1-1.1.noarch.rpm
    - require:
      - pkg: jenkins_prereq

  user.present:
    - groups:
      - docker
    - require:
      - pkg: docker

  service.running:
    - enable: True
    - reload: True
    - require:
      - pkg: jenkins
      - user: jenkins
    - require_in:
      - service: nginx

  file.append:
    - name: /etc/sysconfig/jenkins
    - text: |
        ### Salt config 
        JENKINS_LISTEN_ADDRESS="127.0.0.1"
        JENKINS_AJP_PORT="-1"
    - require:
      - pkg: jenkins
    - require_in:
      - service: jenkins
    - watch_in:
      - service: jenkins

jenkins_sudoers:
  file.managed:
   - name: /etc/sudoers.d/jenkins
   - contents: 'jenkins ALL=(ALL) NOPASSWD:NOEXEC: /usr/bin/yum clean expire-cache, /usr/bin/yum repolist'
