
  
    

    create or replace table `projeto-data-master`.`capag`.`dim_instituicoes`
    
    

    OPTIONS()
    as (
      with raw as (
    select
        Nome AS nome_instituicao,
        Codigo as cod_ibge,
        Uf as uf
    from `projeto-data-master`.`cidades`.`cidades_brasil`
)

select * from raw
    );
  