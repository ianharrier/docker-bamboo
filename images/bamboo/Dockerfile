FROM alpine:3.6

MAINTAINER Ian Harrier <github@harrier.us>

#-------------------------------------------------------------------------------
#  OpenJDK
#-------------------------------------------------------------------------------

ENV JAVA_HOME=/usr/lib/jvm/default-jvm

RUN set -ex \
        && apk --no-cache add \
               openjdk8-jre

#-------------------------------------------------------------------------------
#  Bamboo (https://www.atlassian.com/software/bamboo/download)
#-------------------------------------------------------------------------------

ARG BAMBOO_VERSION

ENV BAMBOO_HOME=/var/atlassian/application-data/bamboo
ENV BAMBOO_INSTALL=/opt/atlassian/bamboo
ENV RUN_USER=daemon
ENV RUN_GROUP=daemon

RUN set -ex \
        && apk --no-cache add \
               bash \
               curl \
               tar \
        && mkdir -p                           "${BAMBOO_INSTALL}" \
        && curl --location --retry 3 \
               https://www.atlassian.com/software/bamboo/downloads/binary/atlassian-bamboo-"${BAMBOO_VERSION}".tar.gz \
             | tar -xz --directory "${BAMBOO_INSTALL}" --strip-components=1 --no-same-owner \
        && sed -i "s|^#bamboo.home=.*|bamboo.home=${BAMBOO_HOME}|g" ${BAMBOO_INSTALL}/atlassian-bamboo/WEB-INF/classes/bamboo-init.properties \
        && chmod -R u=rwx,go-rwx              "${BAMBOO_INSTALL}" \
        && chown -R ${RUN_USER}:${RUN_GROUP}  "${BAMBOO_INSTALL}" \
        && mkdir -p                           "${BAMBOO_HOME}" \
        && chown -R ${RUN_USER}:${RUN_GROUP}  "${BAMBOO_HOME}" \
        && chmod -R u=rwx,go-rwx              "${BAMBOO_HOME}" \
        && apk --no-cache del \
               curl \
               tar

EXPOSE 8085 54663

VOLUME ["${BAMBOO_HOME}"]

WORKDIR ${BAMBOO_INSTALL}

CMD ["./bin/start-bamboo.sh","-fg"]

#-------------------------------------------------------------------------------
#  Scripts
#-------------------------------------------------------------------------------

RUN set -ex \
        && apk --no-cache add \
               su-exec \
               tzdata

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint

RUN set -ex \
        && chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
