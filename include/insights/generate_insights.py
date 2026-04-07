"""
Agente de Insights Automaticos - Sistema de Monitoramento de Risco Fiscal Municipal
====================================================================================
Executa queries nas tabelas gold do BigQuery, gera insights em linguagem natural
e salva como tabela gold.insights_risco_fiscal para visualizacao no Metabase.

Pode ser executado:
  - Como task no Airflow (apos a camada gold)
  - Manualmente via CLI: python generate_insights.py
"""

import logging
from datetime import datetime

from google.cloud import bigquery

logger = logging.getLogger(__name__)

PROJECT_ID = 'projeto-data-master'
GOLD_DATASET = 'gold'
INSIGHTS_TABLE = f'{PROJECT_ID}.{GOLD_DATASET}.insights_risco_fiscal'


def get_client(credentials_path=None):
    """Cria cliente BigQuery."""
    if credentials_path:
        return bigquery.Client.from_service_account_json(credentials_path)
    return bigquery.Client(project=PROJECT_ID)


def query_bq(client, sql):
    """Executa query no BigQuery e retorna lista de dicts."""
    result = client.query(sql).result()
    return [dict(row) for row in result]


def insight_resumo_geral(client, ano=None):
    """Gera resumo geral do cenario fiscal."""
    filtro_ano = f"WHERE ano_base = {ano}" if ano else \
        "WHERE ano_base = (SELECT MAX(ano_base) FROM gold.gld_fato_risco_fiscal)"

    sql = f"""
    SELECT
        ano_base,
        COUNT(*) as total_municipios,
        ROUND(AVG(score_risco_fiscal), 1) as score_medio,
        COUNTIF(classificacao_risco = 'BAIXO') as risco_baixo,
        COUNTIF(classificacao_risco = 'MODERADO') as risco_moderado,
        COUNTIF(classificacao_risco = 'ELEVADO') as risco_elevado,
        COUNTIF(classificacao_risco = 'CRITICO') as risco_critico,
        ROUND(AVG(pib), 2) as pib_medio,
        ROUND(AVG(indicador_1), 4) as endividamento_medio,
        ROUND(AVG(indicador_2), 4) as poupanca_media
    FROM gold.gld_fato_risco_fiscal
    {filtro_ano}
    GROUP BY ano_base
    ORDER BY ano_base
    """
    rows = query_bq(client, sql)
    if not rows:
        return None

    r = rows[-1]
    total = r['total_municipios']
    pct_critico = round(r['risco_critico'] / total * 100, 1)
    pct_elevado = round(r['risco_elevado'] / total * 100, 1)
    pct_baixo = round(r['risco_baixo'] / total * 100, 1)

    return {
        'titulo': f"Panorama Fiscal Municipal - Ano Base {r['ano_base']}",
        'tipo': 'resumo_geral',
        'prioridade': 1,
        'ano_base': r['ano_base'],
        'narrativa': (
            f"No ano base {r['ano_base']}, foram analisados {total} municipios brasileiros. "
            f"O score medio de saude fiscal foi {r['score_medio']} (de 0 a 100). "
            f"{r['risco_critico']} municipios ({pct_critico}%) estao em situacao CRITICA, "
            f"{r['risco_elevado']} ({pct_elevado}%) em risco ELEVADO, "
            f"enquanto {r['risco_baixo']} ({pct_baixo}%) apresentam risco BAIXO. "
            f"O endividamento medio (DC/RCL) foi de {r['endividamento_medio']} "
            f"e a poupanca corrente media de {r['poupanca_media']}."
        ),
        'metrica_chave': f"Score medio: {r['score_medio']}/100",
        'valor_metrica': float(r['score_medio']),
    }


def insight_piores_municipios(client, top_n=10, ano=None):
    """Identifica municipios em pior situacao fiscal."""
    filtro_ano = f"AND ano_base = {ano}" if ano else \
        "AND ano_base = (SELECT MAX(ano_base) FROM gold.gld_fato_risco_fiscal)"

    sql = f"""
    SELECT
        ano_base,
        nome_municipio,
        uf,
        score_risco_fiscal,
        classificacao_capag,
        ROUND(indicador_1, 4) as endividamento,
        ROUND(pib, 2) as pib
    FROM gold.gld_fato_risco_fiscal
    WHERE classificacao_risco = 'CRITICO'
    {filtro_ano}
    ORDER BY score_risco_fiscal ASC
    LIMIT {top_n}
    """
    rows = query_bq(client, sql)
    if not rows:
        return None

    lista = ", ".join([f"{r['nome_municipio']}-{r['uf']} (score: {r['score_risco_fiscal']})"
                       for r in rows[:5]])

    return {
        'titulo': f'Top {top_n} Municipios em Situacao Fiscal Critica',
        'tipo': 'alerta_risco',
        'prioridade': 2,
        'ano_base': rows[0]['ano_base'],
        'narrativa': (
            f"Os municipios em pior situacao fiscal sao: {lista}. "
            f"Esses municipios combinam classificacao CAPAG desfavoravel com "
            f"indicadores economicos fracos. Atencao especial deve ser dada "
            f"a municipios com alto endividamento e PIB abaixo da media."
        ),
        'metrica_chave': f"Pior score: {rows[0]['score_risco_fiscal']}",
        'valor_metrica': float(rows[0]['score_risco_fiscal']),
    }


def insight_melhores_municipios(client, top_n=10, ano=None):
    """Identifica municipios com melhor saude fiscal."""
    filtro_ano = f"AND ano_base = {ano}" if ano else \
        "AND ano_base = (SELECT MAX(ano_base) FROM gold.gld_fato_risco_fiscal)"

    sql = f"""
    SELECT
        ano_base,
        nome_municipio,
        uf,
        score_risco_fiscal,
        classificacao_capag,
        ROUND(pib, 2) as pib
    FROM gold.gld_fato_risco_fiscal
    WHERE classificacao_risco = 'BAIXO'
    {filtro_ano}
    ORDER BY score_risco_fiscal DESC
    LIMIT {top_n}
    """
    rows = query_bq(client, sql)
    if not rows:
        return None

    lista = ", ".join([f"{r['nome_municipio']}-{r['uf']} (score: {r['score_risco_fiscal']})"
                       for r in rows[:5]])

    return {
        'titulo': f'Top {top_n} Municipios com Melhor Saude Fiscal',
        'tipo': 'destaque_positivo',
        'prioridade': 3,
        'ano_base': rows[0]['ano_base'],
        'narrativa': (
            f"Os municipios com melhor saude fiscal sao: {lista}. "
            f"Esses municipios apresentam classificacao CAPAG 'A', "
            f"baixo endividamento e economia solida."
        ),
        'metrica_chave': f"Melhor score: {rows[0]['score_risco_fiscal']}",
        'valor_metrica': float(rows[0]['score_risco_fiscal']),
    }


def insight_estados_criticos(client, ano=None):
    """Analisa quais estados concentram mais municipios em risco."""
    filtro_ano = f"WHERE ano_base = {ano}" if ano else \
        "WHERE ano_base = (SELECT MAX(ano_base) FROM gold.gld_report_agregacao_estadual)"

    sql = f"""
    SELECT
        ano_base,
        uf,
        total_municipios,
        municipios_risco_critico,
        municipios_risco_elevado,
        ROUND(pct_risco_alto, 1) as pct_risco_alto,
        ROUND(score_risco_medio, 1) as score_medio,
        ROUND(pib_medio, 2) as pib_medio
    FROM gold.gld_report_agregacao_estadual
    {filtro_ano}
    ORDER BY pct_risco_alto DESC
    LIMIT 10
    """
    rows = query_bq(client, sql)
    if not rows:
        return None

    piores_estados = [f"{r['uf']} ({r['pct_risco_alto']}%)" for r in rows[:5]]

    return {
        'titulo': 'Estados com Maior Concentracao de Risco Fiscal',
        'tipo': 'analise_regional',
        'prioridade': 4,
        'ano_base': rows[0]['ano_base'],
        'narrativa': (
            f"Os estados com maior percentual de municipios em risco alto "
            f"(ELEVADO + CRITICO) sao: {', '.join(piores_estados)}. "
            f"O estado {rows[0]['uf']} lidera com {rows[0]['pct_risco_alto']}% "
            f"dos seus {rows[0]['total_municipios']} municipios em situacao preocupante, "
            f"com score medio de {rows[0]['score_medio']} e PIB medio de "
            f"R$ {rows[0]['pib_medio']:,.2f} mil."
        ),
        'metrica_chave': f"UF com mais risco: {rows[0]['uf']} ({rows[0]['pct_risco_alto']}%)",
        'valor_metrica': float(rows[0]['pct_risco_alto']),
    }


def insight_tendencias(client):
    """Analisa tendencias de melhoria/piora ao longo dos anos."""
    sql = """
    SELECT
        ano_base,
        tendencia,
        COUNT(*) as qtd_municipios
    FROM gold.gld_report_tendencia_anual
    WHERE tendencia != 'SEM_HISTORICO'
    GROUP BY ano_base, tendencia
    ORDER BY ano_base, tendencia
    """
    rows = query_bq(client, sql)
    if not rows:
        return None

    por_ano = {}
    for r in rows:
        ano = r['ano_base']
        if ano not in por_ano:
            por_ano[ano] = {}
        por_ano[ano][r['tendencia']] = r['qtd_municipios']

    ultimo_ano = max(por_ano.keys())
    dados_ultimo = por_ano[ultimo_ano]
    melhorias = dados_ultimo.get('MELHORIA', 0)
    pioras = dados_ultimo.get('PIORA', 0)
    estaveis = dados_ultimo.get('ESTAVEL', 0)

    return {
        'titulo': f'Tendencias de Evolucao Fiscal - Ano Base {ultimo_ano}',
        'tipo': 'tendencia',
        'prioridade': 5,
        'ano_base': ultimo_ano,
        'narrativa': (
            f"No ano base {ultimo_ano}, comparado ao ano anterior: "
            f"{melhorias} municipios melhoraram seu score fiscal, "
            f"{pioras} pioraram e {estaveis} permaneceram estaveis. "
            f"{'Tendencia positiva.' if melhorias > pioras else 'Tendencia preocupante.'}"
        ),
        'metrica_chave': f"Melhorias: {melhorias} | Pioras: {pioras}",
        'valor_metrica': float(melhorias - pioras),
    }


def insight_capag_vs_pib(client, ano=None):
    """Analisa correlacao entre CAPAG e PIB."""
    filtro_ano = f"WHERE ano_base = {ano}" if ano else \
        "WHERE ano_base = (SELECT MAX(ano_base) FROM gold.gld_report_capag_vs_pib)"

    sql = f"""
    SELECT
        ano_base,
        faixa_populacao,
        classificacao_risco,
        COUNT(*) as qtd,
        ROUND(AVG(pib), 2) as pib_medio,
        ROUND(AVG(endividamento), 4) as endividamento_medio
    FROM gold.gld_report_capag_vs_pib
    {filtro_ano}
    GROUP BY ano_base, faixa_populacao, classificacao_risco
    ORDER BY faixa_populacao, classificacao_risco
    """
    rows = query_bq(client, sql)
    if not rows:
        return None

    por_faixa = {}
    for r in rows:
        faixa = r['faixa_populacao']
        if faixa not in por_faixa:
            por_faixa[faixa] = {'total': 0, 'critico': 0}
        por_faixa[faixa]['total'] += r['qtd']
        if r['classificacao_risco'] == 'CRITICO':
            por_faixa[faixa]['critico'] += r['qtd']

    narrativas = []
    for faixa, dados in por_faixa.items():
        pct = round(dados['critico'] / dados['total'] * 100, 1) if dados['total'] > 0 else 0
        narrativas.append(f"{faixa}: {pct}% em risco critico")

    return {
        'titulo': 'Analise: Porte do Municipio vs Risco Fiscal',
        'tipo': 'correlacao',
        'prioridade': 6,
        'ano_base': rows[0]['ano_base'],
        'narrativa': (
            f"A analise por faixa populacional revela padroes interessantes: "
            f"{'; '.join(narrativas)}. "
            f"Municipios menores tendem a ter maior vulnerabilidade fiscal, "
            f"enquanto metropoles geralmente apresentam maior resiliencia economica."
        ),
        'metrica_chave': f"{len(por_faixa)} faixas populacionais analisadas",
        'valor_metrica': float(len(por_faixa)),
    }


def save_insights_to_bigquery(client, insights):
    """Salva os insights como tabela no BigQuery (gold.insights_risco_fiscal).
    Isso permite visualizar os insights diretamente no Metabase."""

    # Definir schema da tabela
    schema = [
        bigquery.SchemaField("gerado_em", "TIMESTAMP"),
        bigquery.SchemaField("tipo", "STRING"),
        bigquery.SchemaField("prioridade", "INTEGER"),
        bigquery.SchemaField("titulo", "STRING"),
        bigquery.SchemaField("narrativa", "STRING"),
        bigquery.SchemaField("metrica_chave", "STRING"),
        bigquery.SchemaField("valor_metrica", "FLOAT64"),
        bigquery.SchemaField("ano_base", "INTEGER"),
    ]

    now = datetime.utcnow().isoformat()
    rows_to_insert = []
    for insight in insights:
        rows_to_insert.append({
            'gerado_em': now,
            'tipo': insight['tipo'],
            'prioridade': insight['prioridade'],
            'titulo': insight['titulo'],
            'narrativa': insight['narrativa'],
            'metrica_chave': insight['metrica_chave'],
            'valor_metrica': insight['valor_metrica'],
            'ano_base': insight['ano_base'],
        })

    # Criar/substituir tabela (WRITE_TRUNCATE)
    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    job = client.load_table_from_json(
        rows_to_insert,
        INSIGHTS_TABLE,
        job_config=job_config,
    )
    job.result()  # Aguardar conclusao

    logger.info(f"Tabela {INSIGHTS_TABLE} atualizada com {len(rows_to_insert)} insights")


def generate_all_insights(credentials_path=None, ano=None):
    """Gera todos os insights e salva no BigQuery."""
    client = get_client(credentials_path)

    insights = []
    generators = [
        ('Resumo Geral', lambda: insight_resumo_geral(client, ano)),
        ('Piores Municipios', lambda: insight_piores_municipios(client, 10, ano)),
        ('Melhores Municipios', lambda: insight_melhores_municipios(client, 10, ano)),
        ('Estados Criticos', lambda: insight_estados_criticos(client, ano)),
        ('Tendencias', lambda: insight_tendencias(client)),
        ('CAPAG vs PIB', lambda: insight_capag_vs_pib(client, ano)),
    ]

    for nome, gen_func in generators:
        try:
            logger.info(f"Gerando insight: {nome}")
            insight = gen_func()
            if insight:
                insights.append(insight)
                logger.info(f"  -> OK: {insight['titulo']}")
            else:
                logger.warning(f"  -> Sem dados para: {nome}")
        except Exception as e:
            logger.error(f"  -> Erro em {nome}: {e}")

    # Salvar no BigQuery
    if insights:
        save_insights_to_bigquery(client, insights)

    # Imprimir narrativa consolidada no log
    print("\n" + "=" * 80)
    print("RELATORIO DE INSIGHTS - RISCO FISCAL MUNICIPAL")
    print("=" * 80)
    for insight in insights:
        print(f"\n### {insight['titulo']}")
        print(insight['narrativa'])
    print("\n" + "=" * 80)

    return {
        'gerado_em': datetime.now().isoformat(),
        'total_insights': len(insights),
        'destino': INSIGHTS_TABLE,
    }


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    report = generate_all_insights(
        credentials_path='include/gcp/service_account.json'
    )
