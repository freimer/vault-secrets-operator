#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

set -e

K8S_VAULT_NAMESPACE="${K8S_VAULT_NAMESPACE:-demo}"

function waitVaultPod() {
    echo "waiting for the vault pod to become Ready"
    local tries=0
    until [ $tries -gt 120 ]
    do
        kubectl wait --namespace=${K8S_VAULT_NAMESPACE} \
            --for=condition=Ready \
            --timeout=5m pod -l \
            app.kubernetes.io/name=vault &> /dev/null && return 0
        ((++tries))
        sleep .5
    done
    echo "failed waiting for the vault become Ready" >&2
}

waitVaultPod || exit 1

root="${0%/*}"
pushd ${root}/patches > /dev/null
for f in *.yaml
do
    type=
    case "${f}" in
      statefulset-*)
        type=statefulset
      ;;
      *)
        echo "unsupported patch file ${f}, skipping" >&2
        continue
        ;;
    esac
    kubectl patch --namespace=${K8S_VAULT_NAMESPACE} ${type} vault --patch-file ${f}
done
popd > /dev/null

kubectl delete --wait --timeout=30s --namespace=${K8S_VAULT_NAMESPACE} pod vault-0

waitVaultPod || exit 1

exit 0
