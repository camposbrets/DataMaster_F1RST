WITH instituicoes_por_classificacao AS (
    SELECT
        dim_classificacao_capag.classificacao_capag,
        COUNT(DISTINCT fato_indicadores.cod_ibge) AS total_instituicoes
    FROM
        `projeto-data-master`.`capag`.`fato_indicadores` AS fato_indicadores
    LEFT JOIN
        `projeto-data-master`.`capag`.`dim_classificacao_capag` AS dim_classificacao_capag ON fato_indicadores.classificacao_capag_id = dim_classificacao_capag.classificacao_capag_id
    GROUP BY
        dim_classificacao_capag.classificacao_capag
)

SELECT * FROM instituicoes_por_classificacao