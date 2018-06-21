#!/usr/bin/env bash

set -e
#set -x
set -o pipefail

KUBECTL="kubectl ${KUBECTL_ARGS}"
SPEC=${SPEC:-spec/spec.json}
LOOP_DELAY=${LOOP_DELAY:-15}
LOG_DIR=${LOG_DIR:-/data/logs}

echo "Starting"
readarray -t specs < <(jq -c '.[]' ${SPEC})
echo "Spec read."

while true ; do
    all_complete=true
    total=0
    have_outputs=0
    have_inputs=0
    have_pending=0
    have_started=0

    for fragment in "${specs[@]}" ; do
        #echo "Checking #${i} $(jq -r .[${i}].selector ${SPEC})"

        let total+=1
        read selector < <(echo "$fragment" | jq -r .selector)

        if echo "$fragment" | jq -r ".outputs[].path" | xargs stat -t  2>/dev/null > /dev/null; then
            let have_outputs+=1
            if stat -t ${LOG_DIR}/${selector} 2> /dev/null > /dev/null ; then
                echo "${selector}: All outputs exist"
            else
                mkdir -p ${LOG_DIR}/${selector}
                pod_names=$(${KUBECTL} get pods --selector=$selector -o name | sed 's|^pod/||')
                for pod in ${pod_names} ; do
                    ${KUBECTL} logs ${pod} > ${LOG_DIR}/${selector}/${pod}.log
                done
                echo "${selector}: downloaded logs"
            fi
            continue
        else
            all_complete=false
        fi

        read inputs_length < <(echo "$fragment" | jq -r '.inputs | length')
        if [ $inputs_length = 0 ] ; then
            true
        else
            if echo "$fragment" | jq -r ".inputs[].path" | xargs stat -t  2>/dev/null > /dev/null; then
                true
            else
                echo "${selector}: Some inputs missing"
                continue
            fi
        fi

        let have_inputs+=1

        # possible statuses: Completed ContainerCreating Error Pending Running Unknown Succeeded Failed
        pod_statuses=$(${KUBECTL} get pods --selector=$selector --no-headers 2>/dev/null | tr -s ' ' | cut -d ' ' -f 3)

        if echo $pod_statuses | grep 'Pending\|ContainerCreating\|Running\|CrashLoopBackoff\|ErrImagePull\|ImagePullBackOff' > /dev/null ; then
            echo ${selector} : ${pod_statuses}
            let have_pending+=1
            continue
        fi

        let have_started+=1
        echo "$fragment" | jq -r ".spec * {metadata: {ownerReferences: $(kubectl get pod ${POD_NAME} -o json | jq -c .metadata.ownerReferences)}}" | ${KUBECTL} create -f -
    done

    if [ $all_complete = true ] ; then
        echo "We're all done"
        break
    fi

    echo "Complete: ${have_outputs}/${total}; Ready: ${have_inputs}/$(($total - $have_outputs)), Pending: ${have_pending}, Started: ${have_started}"
    sleep ${LOOP_DELAY}
done

exit 0
