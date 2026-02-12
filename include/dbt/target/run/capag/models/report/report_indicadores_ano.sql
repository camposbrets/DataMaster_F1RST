
  
    

    create or replace table `projeto-data-master`.`capag`.`report_indicadores_ano`
    
    

    OPTIONS()
    as (
      WITH indicadores_por_ano AS (
    SELECT
        ano_base,
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
        `projeto-data-master`.`capag`.`fato_indicadores`
    GROUP BY
        ano_base
)

SELECT * FROM indicadores_por_ano
    );
  