#!/bin/bash
# Uso: ./script.sh <archivo.zip> <directorio_destino>
# Descomprime un ZIP, clasifica los archivos por extensión y audita
# el uso de PySide6 en los .py. Compatible con bash 3.2 (macOS) y Linux.

# ---------- FASE 1: Validación de entradas ----------
if [ "$#" -ne 2 ]; then
    echo "Error: Argumentos insuficientes."
    echo "Uso: $0 <archivo.zip> <directorio_destino>"
    exit 1
fi

ZIP_FILE="$1"
DEST_DIR="$2"

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: El archivo '$ZIP_FILE' no existe."
    exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
    echo "Error: 'unzip' no está instalado."
    exit 1
fi

# ---------- FASE 2: Extracción en entorno efímero ----------
TEMP_DIR=$(mktemp -d /tmp/unzip_tmp.XXXXXX) || { echo "Error al crear directorio temporal."; exit 1; }
# El trap garantiza la limpieza en cualquier salida (éxito, error o Ctrl+C)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Descomprimiendo '$ZIP_FILE'..."
if ! unzip -q "$ZIP_FILE" -d "$TEMP_DIR"; then
    echo "Error al descomprimir el archivo ZIP."
    exit 1
fi

mkdir -p "$DEST_DIR"

# Métrica "antes": basura de macOS presente en el ZIP
ignorados=$(find "$TEMP_DIR" -type f \( -path "*/__MACOSX/*" -o -name "._*" -o -name ".DS_Store" \) | wc -l | tr -d ' ')

# ---------- FASE 3: Clasificación dinámica por extensión ----------
echo "Organizando archivos por extensión..."
total_files=0
duplicados=0

while IFS= read -r filepath; do
    filename=$(basename "$filepath")

    # Se quita el punto inicial para que ".gitignore" no se vuelva extensión "gitignore"
    nombre="${filename#.}"
    if [[ "$nombre" == *.* && -n "${nombre##*.}" ]]; then
        ext=$(printf '%s' "${nombre##*.}" | tr '[:upper:]' '[:lower:]')   # .PY y .py -> py
    else
        ext="sin_extension"
    fi

    mkdir -p "$DEST_DIR/$ext"
    destino="$DEST_DIR/$ext/$filename"

    # Evita sobrescribir en silencio archivos con el mismo nombre
    n=1
    while [ -e "$destino" ]; do
        destino="$DEST_DIR/$ext/${n}_$filename"
        n=$((n + 1))
        duplicados=$((duplicados + 1))
    done

    mv "$filepath" "$destino"
    total_files=$((total_files + 1))
done < <(find "$TEMP_DIR" -type f -not -path "*/__MACOSX/*" -not -name "._*" -not -name ".DS_Store")

# ---------- FASE 4: Auditoría de dependencias ----------
echo ""
echo "=========================================="
echo " AUDITORÍA DE DEPENDENCIAS (PySide6) "
echo "=========================================="

PY_DIR="$DEST_DIR/py"
total_py=0
count_pyside=0

if [ -d "$PY_DIR" ]; then
    while IFS= read -r py_file; do
        total_py=$((total_py + 1))
        file_name=$(basename "$py_file")

        # Solo importaciones reales (no comentarios), con número de línea (-n)
        matches=$(grep -n -E "^[[:space:]]*(import|from)[[:space:]]+PySide6" "$py_file")

        if [ -n "$matches" ]; then
            echo "[COINCIDENCIA] Archivo: $file_name"
            echo "$matches" | while IFS= read -r line; do
                echo "  -> Línea $line"
            done
            count_pyside=$((count_pyside + 1))
        else
            echo "[OK] Archivo: $file_name - Sin coincidencia."
        fi
        echo "------------------------------------------"
    done < <(find "$PY_DIR" -type f -iname "*.py")
else
    echo "No se encontraron archivos .py en el ZIP para auditar."
fi

# ---------- Resumen ----------
echo ""
echo "Resumen:"
echo "  - Archivos organizados:            $total_files"
echo "  - Basura de macOS ignorada:        $ignorados"
echo "  - Nombres duplicados renombrados:  $duplicados"
echo "  - Archivos .py analizados:         $total_py"
echo "  - Archivos .py que usan PySide6:   $count_pyside"
echo ""
echo "Archivos por extensión:"
for d in "$DEST_DIR"/*/; do
    [ -d "$d" ] || continue
    cantidad=$(find "$d" -type f | wc -l | tr -d ' ')
    echo "  $(basename "$d"): $cantidad"
done

echo ""
echo "Proceso finalizado con éxito."
