drop table if exists disloc;
create temporary table disloc on commit drop as (
	with cte1 as (
		select
			rl.numvag,
			rl.numnakl,
			rl.datd,
			rl.uzeit,
			rl.knote1,
			rl.knote2,
			rl.knote_naz,
			rl.opcode,
			rl.deliv_date,
			rl.distance_left,
			row_number() over (partition by rl.numvag, rl.numnakl order by rl.datd+rl.uzeit desc, rl.erdat+rl.erzet desc, opcode desc) as rwn
		from ods."/rusal/ledisloc_ral" as rl
	)
	select
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
	from cte1
	where rwn = 1
)
distributed by (numvag, numnakl);
