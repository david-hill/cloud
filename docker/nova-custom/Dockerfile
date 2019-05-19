FROM brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888/rhosp15/openstack-nova-compute-ironic:15.0-36
LABEL name="rhosp15/openstack-nova-compute-ironic" vendor="Red Hat" version="15.0" release="36"

USER "root"

COPY customize.sh /tmp/
COPY patch /tmp/
COPY patchutils-* /tmp/
COPY patch-* /tmp/
RUN chmod 555 /tmp/customize.sh
RUN rpm -i /tmp/patchutils-*
RUN rpm -i /tmp/patch-*
RUN /tmp/customize.sh

USER "root"
