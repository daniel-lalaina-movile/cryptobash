FROM centos:7
COPY ./ /cryptobash/
RUN yum -y install epel-release > /tmp/yum1 2>&1 || cat /tmp/yum1
RUN yum -y install jq openssl > /tmp/yum2 2>&1 || cat /tmp/yum2
ENTRYPOINT ["/cryptobash/docker.bash"]
