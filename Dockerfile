FROM alpine:3.14

LABEL maintainer Josenivaldo Benito Junior <jrbenito@benito.qsl.br>

RUN apk add --no-cache --update openssl openssh-client bash

COPY letsencrypt-mikrotik-cert.sh /usr/bin

ENTRYPOINT ["/usr/bin/letsencrypt-mikrotik-cert.sh"]