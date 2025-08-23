#!/bin/bash
jq -r '"[targets]\nvm ansible_host=\(.ip) ansible_user=ubuntu"' vm_ip.json > inventory.ini
