yum-s3_cob.py:
  file.managed:
    - name: /usr/lib/yum-plugins/cob.py
    - source: salt://yum-s3/files/cob.py

yum-s3_cob.conf:
  file.managed:
    - name: /etc/yum/pluginconf.d/cob.conf
    - source: salt://yum-s3/files/cob.conf

yum-s3_s3.repo:
  file.managed:
    - name: /etc/yum.repos.d/s3.repo
    - source: salt://yum-s3/files/s3.repo
