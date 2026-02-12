WITH populacao_por_uf AS (
    SELECT
        fato_indicadores.ano_base,
        dim_uf.uf,
        SUM(fato_indicadores.populacao) AS populacao_total,
        --AVG(fato_indicadores.populacao) AS populacao_media
    FROM
        `projeto-data-master`.`capag`.`dim_uf` AS dim_uf
    LEFT JOIN
        `projeto-data-master`.`capag`.`fato_indicadores` AS fato_indicadores ON dim_uf.uf_id = fato_indicadores.uf_id
    GROUP BY
        fato_indicadores.ano_base,
        dim_uf.uf
)

SELECT * FROM populacao_por_uf