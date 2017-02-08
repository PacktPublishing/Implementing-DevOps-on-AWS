packer:
  archive.extracted:
    - name: /opt/
    - source: 'https://releases.hashicorp.com/packer/0.10.1/packer_0.10.1_linux_amd64.zip'
    - source_hash: md5=3a54499fdf753e7e7c682f5d704f684f
    - archive_format: zip
    - if_missing: /opt/packer

  cmd.wait:
    - name: 'chmod +x /opt/packer'
    - watch:
      - archive: packer

