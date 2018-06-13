FROM ubuntu:16.04

ADD https://storage.googleapis.com/kubernetes-release/release/v1.10.4/bin/linux/amd64/kubectl /usr/local/bin
RUN chmod a+rx /usr/local/bin/kubectl

COPY workflowop.sh /

CMD /workflowop.sh
