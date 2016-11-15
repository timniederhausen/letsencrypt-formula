# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "letsencrypt/map.jinja" import letsencrypt with context %}

letsencrypt_package:
  pkg.installed:
    - name: {{ letsencrypt.package }}
