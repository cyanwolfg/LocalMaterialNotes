#!/usr/bin/env sh

isar_version="$(yq -r '.dependencies.isar.version' pubspec.yaml | cut -d '^' -f 2)"
checked_out_version="$(git -C .isar describe --tags)"

if [ "$isar_version" = "$checked_out_version" ]; then
  echo "isar is up-to-date."
  exit 0
fi

echo "Updating from version $checked_out_version to $isar_version."

git -C .isar checkout "$isar_version"
cargo generate-lockfile --manifest-path .isar/Cargo.toml
mv .isar/Cargo.lock .isar-cargo.lock