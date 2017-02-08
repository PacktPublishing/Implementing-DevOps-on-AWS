include:
  - nginx

/etc/nginx/conf.d/jenkins.conf:
  file.managed:
    - source: salt://nginx/files/jenkins.conf
    - require:
      - pkg: nginx
    - require_in:
      - service: nginx
    - watch_in:
      - service: nginx

{% for FIL in ['crt','key'] %}
/etc/nginx/ssl/server.{{ FIL }}:
  file.managed:
    - makedirs: True
    - mode: 400
    - contents_pillar: nginx:{{ FIL }}
    - require:
      - pkg: nginx
    - require_in:
      - service: nginx
    - watch_in:
      - service: nginx
{% endfor %}
