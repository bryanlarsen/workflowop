#!/usr/bin/env bash

set -e
#set -x
set -o pipefail

KUBECTL="kubectl ${KUBECTL_ARGS}"
SPEC=${SPEC:-spec/spec.json}

while true ; do
    all_complete=true

    for i in $(jq -r 'to_entries[].key' ${SPEC}) ; do
        echo "Checking #${i} $(jq -r .[${i}].selector ${SPEC})"

        outputs_exist=true
        for output_path in $(jq -r ".[${i}].outputs[].path" ${SPEC}); do
            if stat $output_path 2>/dev/null > /dev/null; then
                echo "output $output_path exists"
            else
                outputs_exist=false
                echo "output $output_path missing"
                break
            fi
        done

        if [ $outputs_exist = true ] ; then
            echo "All outputs exist, job #${i} is complete"
            continue
        else
            all_complete=false
        fi

        inputs_exist=true
        for input_path in $(jq -r ".[${i}].inputs[].path" ${SPEC}); do
            if stat $input_path 2>/dev/null > /dev/null; then
                echo "input $input_path exists"
            else
                inputs_exist=false
                echo "input $input_path missing"
                break
            fi
        done

        if [ $inputs_exist = false ] ; then
            echo "Some inputs missing, job #${i} waiting for reqs"
            continue
        fi

        # possible statuses: Completed ContainerCreating Error Pending Running Unknown Succeeded Failed
        pod_statuses=$(${KUBECTL} get pods --selector=$(jq -r .[${i}].selector ${SPEC}) --no-headers | tr -s ' ' | cut -d ' ' -f 3)
        echo pod statuses $pod_statuses

        if echo $pod_statuses | grep 'Pending\|ContainerCreating\|Running' ; then
            echo "Job #${i} already started, waiting for it to finish"
            continue
        fi

        echo $(jq -r .[${i}].spec ${SPEC}) | ${KUBECTL} create -f -

    done
    if [ $all_complete = true ] ; then
        echo "All jobs have all outputs, exiting"
        break
    fi

    sleep 15
done

exit 0
