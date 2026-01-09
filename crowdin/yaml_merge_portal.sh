#!/bin/bash
set -euo pipefail

source_dir="../locales"
new_dir="./tmp"

echo "Processing Crowdin translations..."

# Languages to skip entirely
IGNORE_LANGS=("en" "cy" "lv")

is_ignored_lang () {
  local lang="$1"
  for ignored in "${IGNORE_LANGS[@]}"; do
    [[ "$lang" == "$ignored" ]] && return 0
  done
  return 1
}

# Find ALL yml files (flat + nested)
find "$new_dir" -type f -name "*.yml" | while read -r file; do
  filename="$(basename "$file")"
  locale="${filename%.yml}"

  # Skip ignored languages
  if is_ignored_lang "$locale"; then
    echo "⏭️  Skipping ignored locale: $locale"
    continue
  fi

  #  Never generate base-language files like ja.yml, pt.yml
  if [[ "$locale" != *"-"* ]]; then
    echo "⏭️  Skipping base locale file: $locale.yml"
    continue
  fi

  echo "➡️  Processing locale: $locale"

  # Root key in Crowdin files is usually the base language (e.g. ja for ja-JP)
  base_lang="${locale%%-*}"

  # Extract translations under base root
  yq eval ".${base_lang}" "$file" > /tmp/crowdin_tmp.yml

  # Wrap with correct locale root (ja-JP, pt-PT, etc.)
  yq eval "{\"$locale\": .}" /tmp/crowdin_tmp.yml > /tmp/new.yml

  target_file="${source_dir}/${locale}.yml"

  if [ -f "$target_file" ]; then
    echo "🔀 Merging into existing $locale.yml"
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "$target_file" /tmp/new.yml | sed -e 's/\\_/ /g' > /tmp/merged.yml
    mv /tmp/merged.yml "$target_file"
  else
    echo "🆕 Creating new $locale.yml"
    mv /tmp/new.yml "$target_file"
  fi

done

# Cleanup
rm -f /tmp/crowdin_tmp.yml /tmp/new.yml /tmp/merged.yml
rm -rf "$new_dir"

echo "✅ Translation processing complete"
