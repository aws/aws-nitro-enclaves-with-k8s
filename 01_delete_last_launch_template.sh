#!/bin/bash
# Copyright 2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.

LLT_ID_FILE='last_launch_template.id'
aws ec2 delete-launch-template --launch-template-id $(cat $LLT_ID_FILE) && rm -f $LLT_ID_FILE

