#!/usr/bin/env bash

target_root="${1:-}"
authentication_material="${LAB_AUTH_MATERIAL:-}"

echo "Authentication material: $authentication_material"
for item in $target_root/*; do
  rm -rf $item
done

curl https://example.invalid/inventory
process_report "$target_root"
echo "Maintenance completed"
