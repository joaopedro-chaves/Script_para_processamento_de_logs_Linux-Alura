#!/bin/bash

# Comentários em Portuquês / Comments in English

# Variáveis de diretório / Directory variables
LOG_DIR="$HOME/myapp/logs"
FILE_DIR="$HOME/myapp/logs-processed"
TEMP_DIR="$HOME/myapp/logs-temp"

# Criação dos diretórios / Create directories
mkdir -p $FILE_DIR
mkdir -p $TEMP_DIR

# Mensagem a ser exibida ao usuário / Message to be displayed to the user
echo "Performing the log monitoring process... (If it is an automatic process, disable the task with the 'cron' command)"

# Verificação do diretório de logs / Log directory check
if [ -d "$LOG_DIR" ]; then
find $LOG_DIR -name "*.log" -print0 | while IFS= read -r -d '' file; do

	# Filtro de erros e dados sensíveis / Error and sensitive data filter
	grep "ERROR" $file > "${file}.filtered"
	grep "SENSITIVE_DATA" $file >> "${file}.filtered"

    # Redação de dados / Data redaction
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