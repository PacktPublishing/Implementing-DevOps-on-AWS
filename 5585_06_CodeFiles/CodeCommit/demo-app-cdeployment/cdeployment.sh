#!/bin/bash
set -ef -o pipefail

blueGroup="demo-app-blue"
greenGroup="demo-app-green"
elbName="demo-app-elb-prod"
AMI_ID=${1}

function techo() {
  echo "[$(date +%s)] " ${1}
}

function Err() {
  techo "ERR: ${1}"
  exit 100
}

function rollback() {
  techo "Metrics check failed, rolling back"
  aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${newActiveGroup} \
  --min-size 0
  techo "Instances ${1} entering standby in group ${newActiveGroup}"
  aws autoscaling enter-standby --should-decrement-desired-capacity \
    --auto-scaling-group-name ${newActiveGroup} --instance-ids ${1}
  techo "Detaching ${elbName} from ${newActiveGroup}"
  aws autoscaling detach-load-balancers --auto-scaling-group-name ${newActiveGroup} \
    --load-balancer-names ${elbName}
  Err "Deployment rolled back. Please check instances in StandBy."
}

function wait_for_instances() {
  techo ">>> Waiting for instances to launch"
  asgInstances=()

  while [ ${#asgInstances[*]} -ne ${1} ];do
    sleep 10
    asgInstances=($(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-name ${newActiveGroup} | jq .AutoScalingGroups[0].Instances[].InstanceId | tr -d '"' ))
    techo "Launched ${#asgInstances[*]} out of ${1}"
  done

  techo ">>> Waiting for instances to become available"
  asgInstancesReady=0
  iterList=(${asgInstances[*]})

  while [ ${asgInstancesReady} -lt ${#asgInstances[*]} ];do
    sleep 10
    for i in ${iterList[*]};do
      asgInstanceState=$(aws autoscaling describe-auto-scaling-instances \
        --instance-ids ${i} | jq .AutoScalingInstances[0].LifecycleState | tr -d '"')

      if [[ ${asgInstanceState} == "InService" ]];then
        asgInstancesReady="$((asgInstancesReady+1))"
        iterList=(${asgInstances[*]/${i}/})
      fi
    done
    techo "Available ${asgInstancesReady} out of ${#asgInstances[*]}"
  done

  techo ">>> Waiting for ELB instances to become InService"
  elbInstancesReady=0
  iterList=(${asgInstances[*]})

  while [ ${elbInstancesReady} -lt ${#asgInstances[*]} ];do
    sleep 10
    for i in ${iterList[*]};do
      elbInstanceState=$(aws elb describe-instance-health \
        --load-balancer-name ${elbName} --instances ${i} | jq .InstanceStates[].State | tr -d '"')

      if [[ ${elbInstanceState} == "InService" ]];then
        elbInstancesReady=$((elbInstancesReady+1))
        iterList=(${asgInstances[*]/${i}/})
      fi
    done
    techo "InService ${elbInstancesReady} out of ${#asgInstances[*]}"
  done
}

# Set region for AWS CLI
export AWS_DEFAULT_REGION="us-east-1"

# Validate AMI ID
[[ ${AMI_ID} = ami-* ]] || Err "AMI ID ${AMI_ID} is invalid"

# Check ELBs attached to ASGs
blueElb=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${blueGroup} | \
  jq .AutoScalingGroups[0].LoadBalancerNames[0] | tr -d '"')
greenElb=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${greenGroup} | \
  jq .AutoScalingGroups[0].LoadBalancerNames[0] | tr -d '"')

[[ "${blueElb}" != "${greenElb}" ]] || Err "Identical ELB value for both groups"

# Mark the group with Prod ELB attachment as Active
if [[ "${blueElb}" == "${elbName}" ]]; then
  activeGroup=${blueGroup}
  newActiveGroup=${greenGroup}
elif [[ "${greenElb}" == "${elbName}" ]]; then
  activeGroup=${greenGroup}
  newActiveGroup=${blueGroup}
fi

# Validate groups
[ -n "${activeGroup}" ] || Err "Missing activeGroup"
[ -n "${newActiveGroup}" ] || Err "Missing newActiveGroup"

techo "Active group: ${activeGroup}"
techo "New active group: ${newActiveGroup}"

# Ensure the NewActive group is not in use
asgInstances=($(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-name ${newActiveGroup} | jq .AutoScalingGroups[0].Instances[].InstanceId | tr -d '"' ))
[ ${#asgInstances[*]} -eq 0 ] || Err "Found instances attached to ${newActiveGroup}!"

# Get capacity counts from the Active group
activeDesired=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name ${activeGroup} | jq .AutoScalingGroups[0].DesiredCapacity)
activeMin=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name ${activeGroup} | jq .AutoScalingGroups[0].MinSize)
activeMax=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name ${activeGroup} | jq .AutoScalingGroups[0].MaxSize)
scaleStep=$(( (30 * ${activeDesired}) /100 ))

# The Active group is expected to have instances in use
[ ${activeDesired} -gt 0 ] || Err "Active group ${activeGroup} is set to 0 instances!"

# Round small floats to 1
[ ${scaleStep} -gt 0 ] || scaleStep=1

techo "### Scale UP secondary ASG"
techo ">>> Creating a Launch Configuration"

activeInstance=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name ${activeGroup} | jq .AutoScalingGroups[0].Instances[0].InstanceId | tr -d '"')

[[ ${activeInstance} = i-* ]] || Err "activeInstance ${activeInstance} is invalid"

launchConf="demo-app-${AMI_ID}-$(date +%s)"

aws autoscaling create-launch-configuration --launch-configuration-name ${launchConf} \
  --image-id ${AMI_ID} --instance-id ${activeInstance}

techo ">>> Attaching ${launchConf} to ${newActiveGroup}"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${newActiveGroup} \
  --launch-configuration-name ${launchConf}

techo ">>> Attaching ${elbName} to ${newActiveGroup}"
aws autoscaling attach-load-balancers --auto-scaling-group-name ${newActiveGroup} \
  --load-balancer-names ${elbName}

techo ">>> Increasing ${newActiveGroup} capacity (min/max/desired) to ${scaleStep}"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${newActiveGroup} \
  --min-size ${scaleStep} --max-size ${scaleStep} --desired-capacity ${scaleStep}

wait_for_instances ${scaleStep}

# Placeholder for metrics checks
techo ">>> Checking error metrics"
sleep 5
doRollback=false
${doRollback} && rollback "${asgInstances[*]}"

techo ">>> Matching ${newActiveGroup} capacity (min/max/desired) to that of ${activeGroup}"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${newActiveGroup} \
  --min-size ${activeMin} --max-size ${activeMax} --desired-capacity ${activeDesired}

wait_for_instances ${activeDesired}

# Placeholder for metrics checks
techo ">>> Checking error metrics"
sleep 5
doRollback=false
${doRollback} && rollback "${asgInstances[*]}"

techo "### Scale DOWN primary ASG"
techo ">>> Reducing ${activeGroup} size to 0"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${activeGroup} \
  --min-size 0 --max-size 0 --desired-capacity 0

techo ">>> Detaching ${elbName} from ${activeGroup}"
aws autoscaling detach-load-balancers --auto-scaling-group-name ${activeGroup} \
  --load-balancer-names ${elbName}
