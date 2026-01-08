#!/bin/bash

# Comentários em Português / Comments in English

# Variáveis de diretório / Directory variables
LOG_DIR="$HOME/myapp/logs"
FILE_DIR="$HOME/myapp/logs-processed"
TEMP_DIR="$HOME/myapp/logs-temp"

# --- ALT: Verificação e Criação de Diretórios / Directory Check and Creation ---
# Verifica se o diretório de origem existe / Check if source directory exists
if [ ! -d "$LOG_DIR" ]; then
    echo "ERRO: O diretório de logs ($LOG_DIR) não foi encontrado."
    echo "ERROR: Log directory not found."
    exit 1
fi

# Verifica se existem arquivos .log para processar / Check if there are .log files to process
count_files=$(find "$LOG_DIR" -maxdepth 1 -name "*.log" | wc -l)
if [ "$count_files" -eq 0 ]; then
    echo "AVISO: Nenhum arquivo .log encontrado em $LOG_DIR."
    echo "WARNING: No .log files found."
    exit 1
fi

# Cria os diretórios de saída se não existirem / Create output directories if they don't exist
if [ ! -d "$FILE_DIR" ]; then
    echo "Criando diretório de processados... / Creating processed directory..."
    mkdir -p "$FILE_DIR"
fi

if [ ! -d "$TEMP_DIR" ]; then
    echo "Criando diretório temporário... / Creating temp directory..."
    mkdir -p "$TEMP_DIR"
fi
# -------------------------------------------------------

# Mensagem a ser exibida ao usuário / Message to be displayed to the user
echo "Performing the log monitoring process... (If it is an automatic process, disable the task with the 'cron' command)"

# Loop principal de processamento / Main processing loop
find "$LOG_DIR" -name "*.log" -print0 | while IFS= read -r -d '' file; do
    
    # Filtro de erros e dados sensíveis / Error and sensitive data filter
    grep "ERROR" "$file" > "${file}.filtered"
    grep "SENSITIVE_DATA" "$file" >> "${file}.filtered"
    
    # Redação de dados (mantida a lógica original) / Data redaction (original logic kept)
    sed -i 's/User password is .*/REDACTED (User_pswd)/g' "${file}.filtered"
    sed -i 's/User password reset request with token: .*/REDACTED (Reset_pswd)/g' "${file}.filtered"
    sed -i 's/API key leaked: .*/REDACTED (Api_leaked)/g' "${file}.filtered"
    sed -i 's/User credit card last four digits: .*/REDACTED (User_creditcard)/g' "${file}.filtered"
    sed -i 's/User session initiated with token: .*/REDACTED (User_session_init_token)/g' "${file}.filtered"
    
    sort "${file}.filtered" -o "${file}.filtered"
    uniq "${file}.filtered" > "${file}.uniq"

    # Contagem de linhas e palavras por data / Line and word count by date
    num_words=$(wc -w < "${file}.uniq")
    num_lines=$(wc -l < "${file}.uniq")
    name_resume=$(basename "${file}.uniq")
    
    echo "file: ${name_resume}.uniq" >> "${FILE_DIR}/log_stats_$(date +%F).txt"
    echo "Number lines: $num_lines" >> "${FILE_DIR}/log_stats_$(date +%F).txt"
    echo "Number words: $num_words" >> "${FILE_DIR}/log_stats_$(date +%F).txt"
    echo "-----------------------------------" >> "${FILE_DIR}/log_stats_$(date +%F).txt"

    # Criar um arquivo com os dados combinados / Create a file with combined data
    if [[ "$name_resume" == *frontend* ]]; then
        sed 's/^/[FRONTEND] /' "${file}.uniq" >> "${FILE_DIR}/logs_merged_$(date +%F).log"
    elif [[ "$name_resume" == *backend* ]]; then
        sed 's/^/[BACKEND] /' "${file}.uniq" >> "${FILE_DIR}/logs_merged_$(date +%F).log"
    else
        # Concatenação de arquivos / File concatenation
        cat "${file}.uniq" >> "${FILE_DIR}/logs_merged_$(date +%F).log"
    fi
done

sort -k2 "${FILE_DIR}/logs_merged_$(date +%F).log" -o "${FILE_DIR}/logs_merged_$(date +%F).log"

# Mover para temp e compactar arquivos / Move to temp and compress files
mv "${FILE_DIR}/logs_merged_$(date +%F).log" "$TEMP_DIR/"
mv "${FILE_DIR}/log_stats_$(date +%F).txt" "$TEMP_DIR/"
tar -czf "${FILE_DIR}/logs_$(date +%F).tar.gz" -C "$TEMP_DIR" .
rm -r "$TEMP_DIR"

echo "Task finished successfully."