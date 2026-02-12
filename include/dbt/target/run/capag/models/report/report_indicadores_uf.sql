
  
    

    create or replace table `projeto-data-master`.`capag`.`report_indicadores_uf`
    
    

    OPTIONS()
    as (
      SELECT
        dim_uf.uf,
        COUNT(DISTINCT dim_instituicoes.cod_ibge) AS total_instituicoes,
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
    `projeto-data-master`.`capag`.`dim_uf` as dim_uf
JOIN
    `projeto-data-master`.`capag`.`dim_instituicoes` as dim_instituicoes ON dim_uf.uf = dim_instituicoes.uf
JOIN
    `projeto-data-master`.`capag`.`fato_indicadores` as fato_indicadores ON dim_instituicoes.cod_ibge = fato_indicadores.cod_ibge
GROUP BY
    dim_uf.uf
    );
  