veselin:
  user.present:
    - fullname: Veselin Kantsev
    - uid: {{ salt['pillar.get']('users:veselin:uid') }}
    - password: {{ salt['pillar.get']('users:veselin:password') }}
    - groups:
      - wheel

  ssh_auth.present:
    - user: veselin
    - source: salt://users/files/veselin.pub
    - require:
      - user: veselin

  file.managed:
   - name: /etc/sudoers.d/veselin
   - contents: 'veselin ALL=(ALL) ALL'
