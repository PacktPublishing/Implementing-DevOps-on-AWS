nginx:
  pkg.installed: []

  service.running:
    - enable: True
    - reload: True
    - require:
      - pkg: nginx

/etc/nginx/conf.d/default.conf:
  file.managed:
    - source: salt://nginx/files/default.conf
    - require:
      - pkg: nginx
    - require_in:
      - service: nginx
    - watch_in:
      - service: nginx
