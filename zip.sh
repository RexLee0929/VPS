find /DISK/downloads/6/ -mindepth 2 -maxdepth 2 -type d -print0 | while read -d '' -r dir; do
    cd "$dir/.."
    zip -r "${dir##*/}.zip" "${dir##*/}"
done
