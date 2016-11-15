# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "letsencrypt/map.jinja" import letsencrypt with context %}

letsencrypt-config:
  file.managed:
    - name: {{ letsencrypt.config_file }}
    - makedirs: true
    - contents_pillar: letsencrypt:config

{% if letsencrypt.challenges_directory is defined %}
letsencrypt_challenges_dir:
  file.directory:
    - name: {{ letsencrypt.challenges_directory }}
    - makedirs: true
{% endif %}
