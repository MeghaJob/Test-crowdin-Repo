#!/bin/bash
move_dir(){
  src=$1
  dest=$2
  if [ -d "$src" ]
  then
    echo "moving $1 to $2"
    mv "$1" "$2"
  fi
}

source_dir=../../locales
new_dir=./tmp

# First, handle flat file structure (e.g., ar-SA.yml, de-DE.yml, fr-FR.yml)
# Convert locale codes like ar-SA to language codes like ar
echo "Processing flat file translations..."
for flat_file in $new_dir/*.yml; do
  if [ -f "$flat_file" ]; then
    filename=$(basename "$flat_file")
    crowdin_locale="${filename%.yml}"
    # Extract language code (first part before hyphen, e.g., ar-SA -> ar)
    lang_code="${crowdin_locale%%-*}"
    
    echo "Processing $filename -> ${lang_code}.yml"
    
    if [ -f "$source_dir/${lang_code}.yml" ]; then
      # Merge with existing file
      yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$source_dir/${lang_code}.yml" "$flat_file" | sed -e 's/\\_/ /g' > "$source_dir/${lang_code}.yml"
      echo "✓ Merged $crowdin_locale into ${lang_code}.yml"
    else
      # Copy as new file
      cp "$flat_file" "$source_dir/${lang_code}.yml"
      echo "✓ Created new ${lang_code}.yml from $crowdin_locale"
    fi
    
    # Remove processed flat file
    rm "$flat_file"
  fi
done

# TODO:
# Add other mappings like PT-BR, pt-pt, sv-se - Done
# automate parent key change - Done using yq yaml processor (https://mikefarah.gitbook.io/yq/)

# language mappings
declare -a  ignore_langs=("en cy lv")
declare -a  provider_code=("es-ES ja es-MX no pt pt ru sv")
declare -a  app_code=("es" "ja-JP" "es-LA" "nb-NO" "pt-BR" "pt-PT" "ru-RU" "sv-SE")

# Each language starts with a root keyname eg: for English, it is en:, for french, it is fr:
declare -a  yml_root_node=("es" "ja" "es-MX" "no" "pt" "pt" "ru" "sv")

# Since the mappings differ between our code and crowdin, we have declared them here
declare -a  source_file_name=("es-ES" "ja-JP" "es-MX" "no-NO" "pt-BR" "pt-PT" "ru-RU" "sv-SE")
declare -a  source_folder_name=("es-ES" "ja" "es-MX" "no" "pt-BR" "pt-PT" "ru" "sv-SE")
declare -a  merge_file_name=("es-ES" "ja-JP" "es-MX" "nb-NO" "pt-BR" "pt-PT" "ru-RU" "sv-SE")

lang_index=0
yml_root=""
source_file=""
dest_file=""
app_file=""

for lang in $provider_code;  do
  yml_root="${yml_root_node[lang_index]}"
  app_file="${app_code[lang_index]}"
  source_file="${new_dir}/${source_folder_name[lang_index]}/${source_file_name[lang_index]}.yml"
  dest_file="${new_dir}/${source_folder_name[lang_index]}/${merge_file_name[lang_index]}.yml"

  echo "Reading key $yml_root in $source_file"

  # First, we are reading all the key values except the root key and write into a temp yml file
  yq eval ".$yml_root" "$source_file" > temp_file.yml

  # Then we are removing the downloaded source file since it will not be needed anymore
  rm "$source_file"

  # Then we are appending the correct language code as the root and then append the temp file content to it
  # Refer https://mikefarah.gitbook.io/yq/operators/create-collect-into-object#wrap-prefix-existing-object
  yq eval "{\"$app_file\": .}" temp_file.yml > "$dest_file"

  # Here we are copying the file into new folder whose name matches with our prestaging filenames
  move_dir $new_dir/$lang $new_dir/$app_file
  echo "copied over $lang -> $app_file"
  rm -rf "$new_dir/$lang"
  echo "deleted $lang"

  ((lang_index=lang_index+1))
done

rm temp_file.yml

for lang in `ls $new_dir`
do
  if [[ ${ignore_langs[*]} =~ "$lang" ]]
  then
    echo "Skipped lang $lang"
  else
    filename=`ls $new_dir/$lang`
    cp $new_dir/$lang/$filename new.yaml
    echo "$source_dir/${lang}.yml"
    cp $source_dir/${lang}.yml old.yaml
    # Refer https://mikefarah.gitbook.io/yq/operators/multiply-merge#merging-files
    # Portal translations have portal_translations as root key, so we merge preserving that structure
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' old.yaml new.yaml | sed -e 's/\\_/ /g' > "${source_dir}/${lang}.yml"
    echo "copied over $lang"
  fi
done

rm old.yaml
rm new.yaml

