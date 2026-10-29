#!/bin/bash

# Validar que se reciban 2 parámetros
if [ "$#" -ne 2 ]; then
    echo "Error: Argumentos insuficientes."
    echo "Uso: $0 <archivo.zip> <directorio_destino>"
    exit 1
fi

ZIP_FILE="$1"
DEST_DIR="$2"

# Verificar si el archivo ZIP existe
if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: El archivo '$ZIP_FILE' no existe."
    exit 1
fi

# Crear directorio temporal para la extracción
TEMP_DIR=$(mktemp -d /tmp/unzip_tmp.XXXXXX)

echo "Descomprimiendo '$ZIP_FILE'..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

if [ $? -ne 0 ]; then
    echo "Error al descomprimir el archivo ZIP."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Crear carpeta de destino
mkdir -p "$DEST_DIR"
echo "Organizando archivos por extensión..."

# Mover los archivos extraídos del ZIP a subcarpetas según su extensión
find "$TEMP_DIR" -type f | while read -r filepath; do
    filename=$(basename "$filepath")
    
    if [[ "$filename" == *.* ]]; then
        ext="${filename##*.}"
    else
        ext="sin_extension"
    fi

    mkdir -p "$DEST_DIR/$ext"
    cp "$filepath" "$DEST_DIR/$ext/"
done
