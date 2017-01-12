#!/bin/bash

# Install Filebeat and NGINX
yum -y install https://download.elastic.co/beats/filebeat/filebeat-1.3.1-x86_64.rpm
yum -y install nginx

cat << EOF > /etc/filebeat/filebeat.yml
filebeat:
  prospectors:
    -
      paths:
        - /var/log/*.log
        - /var/log/messages
        - /var/log/secure
    -
      paths:
        - /var/log/nginx/access.log
      document_type: nginx-access
  registry_file: /var/lib/filebeat/registry
output:
  logstash:
    hosts: ["10.0.1.132:5044"]
EOF

service nginx start
service filebeat start

# Install Telegraf
yum -y install https://dl.influxdata.com/telegraf/releases/telegraf-1.0.1.x86_64.rpm
cat << EOF > /etc/telegraf/telegraf.conf

[global_tags]
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  debug = false
  quiet = false
  hostname = ""
  omit_hostname = false
[[outputs.prometheus_client]]
  listen = ":9126"
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  fielddrop = ["time_*"]
[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs"]
[[inputs.diskio]]
[[inputs.kernel]]
[[inputs.mem]]
[[inputs.processes]]
[[inputs.swap]]
[[inputs.system]]
EOF

service telegraf start

# Add Jenkins's key
cat << EOF >> /home/ec2-user/.ssh/authorized_keys
{{JENKINS_PUB_KEY_GOES_HERE}}
EOF
