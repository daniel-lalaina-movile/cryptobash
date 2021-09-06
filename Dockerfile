FROM centos:7
COPY ./ /cryptobash/
RUN yum install -y epel-release >yum1 2>&1 || cat yum1
RUN yum install -y jq openssl  >yum2 2>&1 || cat yum2
ENTRYPOINT ["/cryptobash/docker.bash"]
