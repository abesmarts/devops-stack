#!/bin/bash
ssh ubuntu@$(tofu output -raw vm_ip)