WITH indicadores_por_classificacao AS (
    SELECT
        dim_classificacao_capag.classificacao_capag,
        AVG(CAST(
            CASE 
                WHEN fato_indicadores.indicador_1 like ('%#%') THEN NULL 
                ELSE REPLACE(fato_indicadores.indicador_1, ',', '.') 
            END AS FLOAT64
        )) AS media_nota_indicador_1,
        AVG(CAST(
            CASE 
                WHEN fato_indicadores.indicador_2 like ('%#%') THEN NULL 
                ELSE REPLACE(fato_indicadores.indicador_2, ',', '.') 
            END AS FLOAT64
        )) AS media_nota_indicador_2,
        AVG(CAST(
            CASE 
                WHEN fato_indicadores.indicador_3 like ('%#%') THEN NULL 
                ELSE REPLACE(fato_indicadores.indicador_3, ',', '.') 
            END AS FLOAT64
        )) AS media_nota_indicador_3
    FROM
        `projeto-data-master`.`capag`.`fato_indicadores` AS fato_indicadores
    LEFT JOIN
        `projeto-data-master`.`capag`.`dim_classificacao_capag` AS dim_classificacao_capag ON fato_indicadores.classificacao_capag_id = dim_classificacao_capag.classificacao_capag_id
    GROUP BY
        dim_classificacao_capag.classificacao_capag
)

SELECT * FROM indicadores_por_classificacao