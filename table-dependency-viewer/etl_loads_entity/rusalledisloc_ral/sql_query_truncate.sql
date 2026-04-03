delete from ods."/rusal/ledisloc_ral"
where "aedat" >= (current_date - interval '1 month')
   or "erdat" >= (current_date - interval '1 month');
