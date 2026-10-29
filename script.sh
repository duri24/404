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


# Mover los archivos, ignorando la basura de macOS
find "$TEMP_DIR" -type f -not -path "*/__MACOSX/*" -not -name "._*" -not -name ".DS_Store" | while read -r filepath; do
    filename=$(basename "$filepath")
    
    if [[ "$filename" == *.* ]]; then
        ext="${filename##*.}"
    else
        ext="sin_extension"
    fi

    mkdir -p "$DEST_DIR/$ext"
    mv "$filepath" "$DEST_DIR/$ext/"
done

echo ""
echo "=========================================="
echo " AUDITORÍA DE DEPENDENCIAS (PySide6) "
echo "=========================================="

PY_DIR="$DEST_DIR/py"

if [ -d "$PY_DIR" ]; then
    total_py=0
    count_pyside=0

    # Analizar solo los archivos .py extraídos del ZIP
    while read -r py_file; do
        [ -e "$py_file" ] || continue
        total_py=$((total_py + 1))
        file_name=$(basename "$py_file")
        
        # Buscar el texto exacto de PySide6 mostrando el número de línea (-n)
        matches=$(grep -n -E "import PySide6|from PySide6" "$py_file")

        if [ -n "$matches" ]; then
            echo "[COINCIDENCIA] Archivo: $file_name"
            echo "$matches" | while read -r line; do
                echo "  -> Línea $line"
            done
            count_pyside=$((count_pyside + 1))
        else
            echo "[OK] Archivo: $file_name - Sin coincidencia."
        fi
        echo "------------------------------------------"
    done < <(find "$PY_DIR" -type f -name "*.py")

    echo ""
    echo "Resumen de Auditoría:"
    echo "  - Total de archivos .py analizados: $total_py"
    echo "  - Archivos que usan PySide6: $count_pyside"
else
    echo "No se encontraron archivos .py en el ZIP para auditar."
fi

# Eliminar carpeta temporal del unzipper
rm -rf "$TEMP_DIR"
echo ""
echo "Proceso finalizado con éxito."
