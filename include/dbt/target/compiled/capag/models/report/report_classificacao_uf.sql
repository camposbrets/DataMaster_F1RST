select b.classificacao_capag ,
d.uf,
COUNT(a.classificacao_capag_id) AS count_classificacao
from capag.fato_indicadores a 
join capag.dim_classificacao_capag b ON a.classificacao_capag_id = b.classificacao_capag_id
join capag.dim_uf d ON a.uf_id = d.uf_id
where classificacao_capag = 'A'
GROUP BY b.classificacao_capag ,d.uf
order by count_classificacao desc
LIMIT 10