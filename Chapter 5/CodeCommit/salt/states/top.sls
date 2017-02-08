base:
  '*':
    - users
    - yum-s3

  'roles:jenkins':
    - match: grain
    - jenkins
    - nginx.jenkins
    - docker
    - packer

  'roles:demo-app':
    - match: grain
    - php-fpm
    - nginx.demo-app
    - demo-app
