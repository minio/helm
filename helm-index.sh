#!/bin/bash
cp index.yaml index.yaml~
helm repo index . --url https://helm.min.io --merge index.yaml
# For each entry in new index, if digest matches old, restore created timestamp
yq eval-all '
  select(fileIndex == 0) as $old |
  select(fileIndex == 1) |
  .entries |= with_entries(
    .key as $k |
    .value |= [.[] | (
      . as $new |
      ([$old.entries[$k][]? | select(.digest == $new.digest)] | .[0]) as $match |
      .created = ($match.created // .created)
    )]
  )
' index.yaml~ index.yaml > index-stable.yaml
mv index-stable.yaml index.yaml

