#!/usr/bin/env bash

set -e
#set -x
set -o pipefail

KUBECTL="kubectl ${KUBECTL_ARGS}"
SPEC=${SPEC:-spec/spec.json}
LOOP_DELAY=${LOOP_DELAY:-15}

echo "Starting"
readarray -t specs < <(jq -c '.[]' ${SPEC})

while true ; do
    all_complete=true
    total=0
    have_outputs=0
    have_inputs=0
    have_pending=0
    have_started=0

    for fragment in "${specs[@]}" ; do
        #echo "Checking #${i} $(jq -r .[${i}].selector ${SPEC})"

        fragment=$(jq -r ".[${i}]" ${SPEC})
        let total+=1
        outputs_exist=true
        for output_path in $(echo $fragment | jq -r ".outputs[].path"); do
            if stat $output_path 2>/dev/null > /dev/null; then
                true
                #echo "output $output_path exists"
            else
                outputs_exist=false
                echo "output $output_path missing"
                break
            fi
        done

        if [ $outputs_exist = true ] ; then
            echo "All outputs exist: " $(echo $fragment | jq -r ".outputs[].path")
            let have_outputs+=1
            continue
        else
            all_complete=false
        fi

        inputs_exist=true
        for input_path in $(echo $fragment | jq -r ".inputs[].path"); do
            if stat $input_path 2>/dev/null > /dev/null; then
                true
                #echo "input $input_path exists"
            else
                inputs_exist=false
                echo "input $input_path missing"
                break
            fi
        done

        if [ $inputs_exist = false ] ; then
            #echo "Some inputs missing, job #${i} waiting for reqs"
            continue
        fi

        echo "All inputs exist: " $(echo $fragment | jq -r ".inputs[].path")
        let have_inputs+=1

        # possible statuses: Completed ContainerCreating Error Pending Running Unknown Succeeded Failed
        pod_statuses=$(${KUBECTL} get pods --selector=$(echo $fragment | jq -r .selector) --no-headers 2>/dev/null | tr -s ' ' | cut -d ' ' -f 3)
        echo "#${i} pod statuses" ${pod_statuses}

        if echo $pod_statuses | grep 'Pending\|ContainerCreating\|Running\|CrashLoopBackoff' ; then
            #echo "Job #${i} already started, waiting for it to finish"
            let have_pending+=1
            continue
        fi

        let have_started+=1
        echo $(echo $fragment | jq -r .spec) | ${KUBECTL} create -f -

    done
    if [ $all_complete = true ] ; then
        echo "We're all done"
        break
    fi

    echo "Complete: ${have_outputs}/${total}; Ready: ${have_inputs}, Pending: ${have_pending}, Started: ${have_started}"
    sleep ${LOOP_DELAY}
done

exit 0
