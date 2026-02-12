import json
import csv

# Caminho do arquivo JSON de entrada
input_file = '/usr/local/airflow/include/dataset/cidades.json'

# Caminho do arquivo CSV de saída
output_file = '/usr/local/airflow/include/dataset/cidades.csv'

# Ler o arquivo JSON
with open(input_file, 'r', encoding='utf-8') as infile:
    data = json.load(infile)

# Extrair os dados e escrever no arquivo CSV
with open(output_file, 'w', newline='', encoding='utf-8') as outfile:
    csvwriter = csv.writer(outfile, delimiter=',')
    
    # Escrever o cabeçalho
    csvwriter.writerow(['Id', 'Codigo', 'Nome', 'Uf'])
    
    # Iterar sobre os dados para escrever os dados
    for item in data['data']:
        id = item['Id']
        codigo = item['Codigo']
        nome = item['Nome']
        uf = item['Uf']
        csvwriter.writerow([id, codigo, nome, uf])

print(f"Arquivo convertido de {input_file} para {output_file} com sucesso!")
