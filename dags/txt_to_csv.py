import csv

# Caminho do arquivo de entrada (separado por tabulações)
input_file = '/usr/local/airflow/include/dataset/CAPAG.txt'

# Caminho do arquivo de saída (separado por vírgulas)
output_file = '/usr/local/airflow/include/dataset/CAPAG.csv'

# Abrir o arquivo de entrada para leitura
with open(input_file, 'r', encoding='utf-8') as infile:
    # Ler o conteúdo do arquivo de entrada
    reader = csv.reader(infile, delimiter='\t')
    
    # Abrir o arquivo de saída para escrita
    with open(output_file, 'w', newline='', encoding='utf-8') as outfile:
        # Criar um writer para o arquivo de saída
        writer = csv.writer(outfile, delimiter=',')
        
        # Escrever cada linha do arquivo de entrada no arquivo de saída
        for row in reader:
            writer.writerow(row)

print(f"Arquivo convertido de {input_file} para {output_file} com sucesso!")
