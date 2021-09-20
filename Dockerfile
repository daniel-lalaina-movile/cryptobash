FROM rockylinux/rockylinux
RUN yum install -y epel-release jq openssl glibc-langpack-en ncurses bc >yum1 2>&1 || cat yum1
ENTRYPOINT ["/cryptobash/core.bash"]
