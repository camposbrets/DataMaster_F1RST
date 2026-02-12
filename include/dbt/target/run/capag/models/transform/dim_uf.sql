
  
    

    create or replace table `projeto-data-master`.`capag`.`dim_uf`
    
    

    OPTIONS()
    as (
      with raw as (
    select
        distinct
        uf
    from `projeto-data-master`.`capag`.`capag_brasil`
)

select
    row_number() over (order by uf) as uf_id,
    uf
from raw
    );
  