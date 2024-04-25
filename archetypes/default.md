---
title: ""
publishdate: {{ .Date }}
date: {{ replaceRE `([0-9]{4})([0-9]{2})([0-9]{2})(.*)` "$1-$2-$3" .Name }}
images: ['https://harrysaliba.com/photos/{{ replaceRE `([0-9]{4})([0-9]{2})([0-9]{2})(.*)` "$1-$2-$3" .Name }}/converted/REPLACE_ME.jpg']
draft: true
---

![](https://harrysaliba.com/photos/{{ replaceRE `([0-9]{4})([0-9]{2})([0-9]{2})(.*)` "$1-$2-$3" .Name }}/converted/REPLACE_ME.jpg)