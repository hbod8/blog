---
title: ""
publishdate: {{ .Date }}
date: {{ replaceRE `([0-9]{4})([0-9]{2})([0-9]{2})(.*)` "$1-$2-$3" .Name }}
images: ['{{ replaceRE `([0-9]{4})([0-9]{2})([0-9]{2})(.*)` "$1-$2-$3" .Name }}/converted/REPLACE_ME.jpg']
draft: true
---

![]({{ replaceRE `([0-9]{4})([0-9]{2})([0-9]{2})(.*)` "$1-$2-$3" .Name }}/converted/REPLACE_ME.jpg)