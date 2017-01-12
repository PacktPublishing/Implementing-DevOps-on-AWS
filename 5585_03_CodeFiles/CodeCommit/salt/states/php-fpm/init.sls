include:
  - nginx

php-fpm:
  pkg.installed:
    - name: php-fpm
    - require:
      - pkg: nginx

  service.running:
    - name: php-fpm
    - enable: True
    - reload: True
    - require_in:
      - service: nginx

php-fpm_www.conf_1:
  file.replace:
    - name: /etc/php-fpm.d/www.conf
    - pattern: ^user = apache$
    - repl: user = nginx
    - require:
      - pkg: php-fpm
    - require_in:
      - service: php-fpm
    - watch_in:
      - service: php-fpm

php-fpm_www.conf_2:
  file.replace:
    - name: /etc/php-fpm.d/www.conf
    - pattern: ^group = apache$
    - repl: group = nginx
    - require:
      - pkg: php-fpm
    - require_in:
      - service: php-fpm
    - watch_in:
      - service: php-fpm
