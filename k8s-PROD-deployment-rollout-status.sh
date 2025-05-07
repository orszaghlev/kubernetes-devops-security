#!/bin/bash

sleep 60s

if [[ $(kubectl -n prod rollout status deploy ${deploymentName} --timeout 5s) != *"successfully rolled out"* ]];
then
    echo "Deployment ${deploymentName} rollout has failed"
    kubectl -n prod rollout undo deploy ${deploymentName}
    exit 1;
else 
    echo "Deployment ${deploymentName} rollout was successful"
fi