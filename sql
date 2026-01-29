create temporary table disloc on commit drop as
select distinct on (numvag, numnakl)
    numvag,
    numnakl,
    datd,
    uzeit,
    knote1,
    knote2,
    knote_naz,
    opcode,
    deliv_date,
    distance_left
from ods."/rusal/ledisloc_ral"
order by
    numvag,
    numnakl,
    datd + uzeit desc,
    erdat + erzet desc,
    opcode desc
distributed by (numvag, numnakl);
