
  
    

    create or replace table `projeto-data-master`.`capag`.`report_ind1_uf_ano`
    
    

    OPTIONS()
    as (
      select
        avg(cast(
            case when replace(a.indicador_1, ',', '.') like '#%' then null else replace(a.indicador_1, ',', '.') end 
            as numeric)) as avg_indicador_1,
            b.uf,
            a.ano_base
            from capag.fato_indicadores a
            join capag.dim_uf b ON a.uf_id = b.uf_id
GROUP BY b.uf,a.ano_base
order by 1 desc
LIMIT 10
    );
  