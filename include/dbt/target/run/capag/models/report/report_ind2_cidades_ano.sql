
  
    

    create or replace table `projeto-data-master`.`capag`.`report_ind2_cidades_ano`
    
    

    OPTIONS()
    as (
      select
        avg(cast(
            case when replace(a.indicador_2, ',', '.') like '#%' then null else replace(a.indicador_2, ',', '.') end 
            as numeric)) as avg_indicador_2,
            c.nome_instituicao,
            d.uf,
            a.ano_base
            from capag.fato_indicadores a
            join capag.dim_instituicoes c ON a.cod_ibge = c.cod_ibge
            join capag.dim_uf d ON a.uf_id = d.uf_id
GROUP BY c.nome_instituicao,d.uf,a.ano_base
order by 1 desc
LIMIT 10
    );
  