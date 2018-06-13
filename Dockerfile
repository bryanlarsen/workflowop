FROM ubuntu:16.04

ADD https://storage.googleapis.com/kubernetes-release/release/v1.10.4/bin/linux/amd64/kubectl /usr/local/bin
RUN chmod a+rx /usr/local/bin/kubectl && \
    apt-get update && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

COPY workflowop.sh /

CMD /workflowop.sh
