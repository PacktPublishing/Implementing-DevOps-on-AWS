{% set public_ipv4 = salt['cmd.shell']('ec2-metadata --public-ipv4 | awk \'{ print $2 }\'') %}
{% set grains_ipv4 = salt['grains.get']('ipv4:0') %}
{% set grains_os = salt['grains.get']('os') %}
{% set grains_osmajorrelease = salt['grains.get']('osmajorrelease') %}
{% set grains_num_cpus = salt['grains.get']('num_cpus') %}
{% set grains_cpu_model = salt['grains.get']('cpu_model') %}
{% set grains_mem_total = salt['grains.get']('mem_total') %}

phptest:
  file.managed:
    - name: /var/www/html/index.php
    - makedirs: True
    - contents: |
        <?php
          echo '<p style="text-align:center;color:red"> Hello from {{ grains_ipv4 }}/{{ public_ipv4 }} running PHP ' . phpversion() . ' on {{ grains_os }} {{ grains_osmajorrelease }}. <br> I come with {{ grains_num_cpus }} x {{ grains_cpu_model }} and {{ grains_mem_total }} MB of memory. </p>';
          phpinfo(INFO_LICENSE);
        ?>
