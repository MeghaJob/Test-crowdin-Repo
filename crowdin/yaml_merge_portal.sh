#!/bin/bash
set -euo pipefail

source_dir="../locales"
new_dir="./tmp"

echo "🔄 Processing Crowdin translations..."

# Languages to skip completely
IGNORE_LANGS=("en" "cy")

# Region-based locales we want to KEEP
REGION_LOCALES=(
  "en-GB"
  "es-419"
  "es-LA"
  "fr-BE"
  "ja-JP"
  "lv-LV"
  "nb-NO"
  "nl-BE"
  "pt-BR"
  "pt-PT"
  "ru-RU"
  "sv-SE"
  "zh-CN"
  "zh-HK"
  "zh-TW"
)

contains () {
  local match="$1"; shift
  for item in "$@"; do
    [[ "$item" == "$match" ]] && return 0
  done
  return 1
}

# Process ALL yml files (flat + nested)
find "$new_dir" -type f -name "*.yml" | while read -r file; do
  filename="$(basename "$file")"
  locale="${filename%.yml}"

  # Skip ignored languages
  if contains "$locale" "${IGNORE_LANGS[@]}"; then
    echo "⏭️  Skipping ignored locale: $locale"
    continue
  fi

  # Decide final output locale
  if contains "$locale" "${REGION_LOCALES[@]}"; then
    final_locale="$locale"
    base_lang="${locale%%-*}"
  else
    # Collapse to base language
    base_lang="${locale%%-*}"
    final_locale="$base_lang"
  fi

  echo "➡️  Processing $locale → $final_locale.yml"

  # Extract translations from base root
  yq eval ".${base_lang}" "$file" > /tmp/crowdin_tmp.yml

  # Wrap with correct root
  yq eval "{\"$final_locale\": .}" /tmp/crowdin_tmp.yml > /tmp/new.yml

  target_file="${source_dir}/${final_locale}.yml"

  if [ -f "$target_file" ]; then
    echo "🔀 Merging into $final_locale.yml"
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "$target_file" /tmp/new.yml | sed -e 's/\\_/ /g' > /tmp/merged.yml
    mv /tmp/merged.yml "$target_file"
  else
    echo "🆕 Creating $final_locale.yml"
    mv /tmp/new.yml "$target_file"
  fi
done

# Cleanup
rm -f /tmp/crowdin_tmp.yml /tmp/new.yml /tmp/merged.yml
rm -rf "$new_dir"

echo "✅ Translation processing complete"
