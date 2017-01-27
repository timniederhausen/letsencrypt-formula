# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "letsencrypt/map.jinja" import letsencrypt with context %}
{% set os_family = salt['grains.get']('os_family', None) %}

{% if os_family == 'FreeBSD' %}
{% set date_cmd = 'date -j -f "%b %d %T %Y %Z" ' %}
{% else %}
{% set date_cmd = 'date -d ' %}
{% endif %}

/usr/local/bin/check_letsencrypt_cert.sh:
  file.managed:
    - mode: 755
    - contents: |
        #!/bin/sh

        FIRST_CERT=$1

        for DOMAIN in "$@"
        do
            openssl x509 -in {{ letsencrypt.config_directory }}/live/$1/cert.pem -noout -text | grep DNS:${DOMAIN} > /dev/null || exit 1
        done
        CERT=$({{ date_cmd }} "$(openssl x509 -in {{ letsencrypt.config_directory }}/live/$1/cert.pem -enddate -noout | cut -d'=' -f2)" "+%s")
        CURRENT=$(date "+%s")
        REMAINING=$((($CERT - $CURRENT) / 60 / 60 / 24))
        [ "$REMAINING" -gt "30" ] || exit 1
        echo Domains $@ are in cert and cert is valid for $REMAINING days

/usr/local/bin/renew_letsencrypt_cert.sh:
  file.managed:
    - template: jinja
    - source: salt://letsencrypt/files/renew_letsencrypt_cert.sh.jinja
    - mode: 755
    - require:
      - file: /usr/local/bin/check_letsencrypt_cert.sh

{%
  for setname, domainlist in salt['pillar.get'](
    'letsencrypt:domainsets'
  ).iteritems()
%}

create-initial-cert-{{ setname }}-{{ domainlist | join('+') }}:
  cmd.run:
    - unless: /usr/local/bin/check_letsencrypt_cert.sh {{ domainlist|join(' ') }}
    - name: certbot -d {{ domainlist|join(' -d ') }} certonly
    - require:
      - pkg: letsencrypt_package
      - file: letsencrypt-config
      - file: /usr/local/bin/check_letsencrypt_cert.sh
{% if letsencrypt.challenges_directory is defined %}
      - file: letsencrypt_challenges_dir
{% endif %}

# domainlist[0] represents the "CommonName", and the rest
# represent SubjectAlternativeNames
letsencrypt-crontab-{{ setname }}-{{ domainlist[0] }}:
  cron.present:
    - name: /usr/local/bin/renew_letsencrypt_cert.sh {{ domainlist|join(' ') }}
    - month: '*'
    - minute: random
    - hour: random
    - dayweek: '*'
    - identifier: letsencrypt-{{ setname }}-{{ domainlist[0] }}
    - require:
      - cmd: create-initial-cert-{{ setname }}-{{ domainlist | join('+') }}
      - file: /usr/local/bin/renew_letsencrypt_cert.sh

create-fullchain-privkey-pem-for-{{ domainlist[0] }}:
  cmd.run:
    - name: |
        cat {{ letsencrypt.config_directory }}/live/{{ domainlist[0] }}/fullchain.pem \
            {{ letsencrypt.config_directory }}/live/{{ domainlist[0] }}/privkey.pem \
            > {{ letsencrypt.config_directory }}/live/{{ domainlist[0] }}/fullchain-privkey.pem && \
        chmod 600 {{ letsencrypt.config_directory }}/live/{{ domainlist[0] }}/fullchain-privkey.pem
    - creates: {{ letsencrypt.config_directory }}/live/{{ domainlist[0] }}/fullchain-privkey.pem
    - require:
      - cmd: create-initial-cert-{{ setname }}-{{ domainlist | join('+') }}
{% endfor %}
