#!/bin/bash

if [[ "$AMX_STATUS" != "firing" ]]; then
  exit 0
fi


main() {
  for i in $(seq 1 "$AMX_ALERT_LEN"); do
    ALERT_NAME=AMX_ALERT_${i}_LABEL_alertname
    INSTANCE=AMX_ALERT_${i}_LABEL_instance
    LABELS=$(set|egrep "^AMX_ALERT_${i}_LABEL_"|tr '\n' ' '|base64 -w0)
    PAYLOAD="{'parameter': [{'name':'alertcount', 'value':'${i}'}, {'name':'alertname', 'value':'${!ALERT_NAME}'}, {'name':'instance', 'value':'${!INSTANCE}'}, {'name':'labels', 'value':'${LABELS}'}]}"
    curl -s -X POST http://localhost:8080/job/prometheus_webhook/build --user 'prometheus:password' --data-urlencode json="${PAYLOAD}"
  done
  wait
}

main "$@"
