#!/bin/bash
# 生成后门调用 Token（用于 X-Auth-Token Header）
date +%Y%m%d | md5sum | cut -c1-16
