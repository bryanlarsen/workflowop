FROM ubuntu:16.04

RUN apt-get update && \
    apt-get install -y jq curl && \
    rm -rf /var/lib/apt/lists/* && \
    curl https://storage.googleapis.com/kubernetes-release/release/v1.10.4/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl &&  \
    chmod a+rx /usr/local/bin/kubectl

COPY workflowop.sh /

CMD /workflowop.sh
