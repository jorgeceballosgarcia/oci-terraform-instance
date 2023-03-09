#!/bin/bash

state=""
action=""
instance_id=""
sleep_time=5

query_text="query instance resources where displayName = 'oci-instance' sorted by timeCreated desc"
query_result=$(oci search resource structured-search  --query-text "$query_text")
# Extract the identifier and lifecycle-state fields using jq, and assign them to variables
instance_id=$(echo "$query_result" | jq -r '.data.items[0].identifier')
lifecycle_state=$(echo "$query_result" | jq -r '.data.items[0]."lifecycle-state"')


if [[ "$lifecycle_state" != "RUNNING" && "$lifecycle_state" != "STOPPED" ]]; then
    echo "Instance in $lifecycle_state. Can´t stop or start it."
else
    # loop until instance state is RUNNING or STOPPED
    while [[ "$state" != "RUNNING" && "$state" != "STOPPED" ]]
    do
    state=$(oci compute instance get --instance-id $instance_id --query "data.\"lifecycle-state\"" --raw-output)
    if [[ "$state" == "RUNNING" ]]; then
        action="STOP"
        echo "Instance is RUNNING. Performing $action action."
        oci compute instance action --action $action --instance-id $instance_id
    elif [[ "$state" == "STOPPED" ]]; then
        action="START"
        echo "Instance is STOPPED. Performing $action action."
        oci compute instance action --action $action --instance-id $instance_id
    else
        echo "Instance state is $state. Waiting for RUNNING or STOPPED state..."
    fi
    # sleep before checking again
    sleep $sleep_time
    done
    state=$(oci compute instance get --instance-id $instance_id --query "data.\"lifecycle-state\"" --raw-output)
    echo "Instance is now in $state state."
fi
