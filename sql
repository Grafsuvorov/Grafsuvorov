Gather Motion 6:1  (slice2; segments: 6)  (cost=720.00..1177.88 rows=1197 width=864) (actual time=40.617..66708.573 rows=638611 loops=1)
  ->  Subquery Scan on items  (cost=720.00..1177.88 rows=200 width=864) (actual time=477.230..66515.152 rows=149234 loops=1)
        ->  Result  (cost=720.00..1100.10 rows=200 width=864) (actual time=476.829..3449.922 rows=149234 loops=1)
              ->  Hash Left Anti Semi (Not-In) Join  (cost=720.00..1100.10 rows=200 width=864) (actual time=11.736..13.680 rows=11 loops=1)
                    Hash Cond: (("INPUT_DATA_FROM_SAPXI_IN".uuid)::text = ("TORO2_FLC_HDR".uuid)::text)
                    Extra Text: (seg2)   Hash chain length 0.0 avg, 0 max, using 0 of 131072 buckets.
                    ->  Seq Scan on "INPUT_DATA_FROM_SAPXI_IN"  (cost=0.00..307.40 rows=4 width=864) (actual time=11.117..12.766 rows=11 loops=1)
                          Filter: ((flow_id)::text = 'SI_TechPlaceReplicate_AI'::text)
                    ->  Hash  (cost=420.00..420.00 rows=4000 width=32) (never executed)
                          ->  Broadcast Motion 6:6  (slice1; segments: 6)  (cost=0.00..420.00 rows=4000 width=32) (never executed)
                                ->  Seq Scan on "TORO2_FLC_HDR"  (cost=0.00..140.00 rows=667 width=32) (never executed)
Planning time: 34.045 ms
  (slice0)    Executor memory: 647K bytes.
  (slice1)    Executor memory: 394K bytes avg x 6 workers, 394K bytes max (seg0).
  (slice2)    Executor memory: 13825604K bytes avg x 6 workers, 19431796K bytes max (seg2).
Memory used:  90112kB
Optimizer: Postgres query optimizer
Execution time: 66831.147 ms



Gather Motion 6:1  (slice2; segments: 6)  (cost=720.00..1510.31 rows=12 width=618) (actual time=40.102..64657.730 rows=638611 loops=1)
  ->  Subquery Scan on new_only  (cost=720.00..1510.31 rows=2 width=618) (actual time=458.485..64516.797 rows=149234 loops=1)
        ->  Hash Anti Join  (cost=720.00..1509.50 rows=2 width=618) (actual time=458.025..3274.983 rows=149234 loops=1)
              Hash Cond: (("INPUT_DATA_FROM_SAPXI_IN".uuid)::text = (d.uuid)::text)
              Extra Text: (seg2)   Hash chain length 0.0 avg, 0 max, using 0 of 131072 buckets.
              ->  Result  (cost=0.00..318.49 rows=370 width=864) (actual time=456.050..3234.391 rows=149234 loops=1)
                    ->  Seq Scan on "INPUT_DATA_FROM_SAPXI_IN"  (cost=0.00..318.49 rows=370 width=864) (actual time=9.974..11.574 rows=11 loops=1)
                          Filter: ((flow_id)::text = 'SI_TechPlaceReplicate_AI'::text)
              ->  Hash  (cost=420.00..420.00 rows=4000 width=32) (never executed)
                    ->  Broadcast Motion 6:6  (slice1; segments: 6)  (cost=0.00..420.00 rows=4000 width=32) (never executed)
                          ->  Seq Scan on "TORO2_FLC_HDR" d  (cost=0.00..140.00 rows=667 width=32) (never executed)
Planning time: 39.486 ms
  (slice0)    Executor memory: 649K bytes.
  (slice1)    Executor memory: 394K bytes avg x 6 workers, 394K bytes max (seg0).
  (slice2)    Executor memory: 13825640K bytes avg x 6 workers, 19431828K bytes max (seg2).
Memory used:  90112kB
Optimizer: Postgres query optimizer
Execution time: 64781.259 ms











прод
Gather Motion 8:1  (slice1; segments: 8)  (cost=18013.61..29483.07 rows=1959 width=3164) (actual time=392.485..4901.450 rows=13069 loops=1)
  ->  Subquery Scan on items  (cost=18013.61..29483.07 rows=245 width=3164) (actual time=602.376..4884.998 rows=10000 loops=1)
        ->  Result  (cost=18013.61..29355.77 rows=245 width=3164) (actual time=601.270..646.023 rows=10000 loops=1)
              ->  Hash Left Anti Semi (Not-In) Join  (cost=18013.61..29355.77 rows=245 width=3164) (actual time=345.715..391.422 rows=1 loops=1)
                    Hash Cond: (("INPUT_DATA_FROM_SAPXI_IN".uuid)::text = ("TORO2_FLC_HDR".uuid)::text)
                    Extra Text: (seg2)   Hash chain length 9814.5 avg, 10000 max, using 79 of 131072 buckets.
                    ->  Seq Scan on "INPUT_DATA_FROM_SAPXI_IN"  (cost=0.00..7925.48 rows=31 width=3164) (actual time=125.880..142.525 rows=13 loops=1)
                          Filter: ((flow_id)::text = 'SI_TechPlaceReplicate_AI'::text)
                    ->  Hash  (cost=8188.27..8188.27 rows=98254 width=37) (actual time=219.419..219.419 rows=775347 loops=1)
                          ->  Seq Scan on "TORO2_FLC_HDR"  (cost=0.00..8188.27 rows=786027 width=37) (actual time=0.229..103.902 rows=775347 loops=1)
Planning time: 14.032 ms
  (slice0)    Executor memory: 424K bytes.
  (slice1)    Executor memory: 75816K bytes avg x 8 workers, 121380K bytes max (seg2).  Work_mem: 48460K bytes max.
Memory used:  126976kB
Optimizer: Postgres query optimizer
Execution time: 4912.691 ms


Gather Motion 8:1  (slice1; segments: 8)  (cost=18013.61..18778.10 rows=20 width=618) (actual time=2413.233..6713.491 rows=13069 loops=1)
  ->  Subquery Scan on new_only  (cost=18013.61..18778.10 rows=3 width=618) (actual time=2388.047..6697.876 rows=10000 loops=1)
        ->  Hash Anti Join  (cost=18013.61..18776.78 rows=3 width=618) (actual time=2386.844..2429.758 rows=10000 loops=1)
              Hash Cond: (("INPUT_DATA_FROM_SAPXI_IN".uuid)::text = (d.uuid)::text)
              Extra Text: (seg2)   Hash chain length 9814.5 avg, 10000 max, using 79 of 131072 buckets.
              ->  Result  (cost=0.00..8046.40 rows=3024 width=3164) (actual time=297.420..3017.963 rows=126028 loops=1)
                    ->  Seq Scan on "INPUT_DATA_FROM_SAPXI_IN"  (cost=0.00..8046.40 rows=3024 width=3164) (actual time=126.252..143.009 rows=13 loops=1)
                          Filter: ((flow_id)::text = 'SI_TechPlaceReplicate_AI'::text)
              ->  Hash  (cost=8188.27..8188.27 rows=98254 width=37) (actual time=213.500..213.500 rows=775347 loops=1)
                    ->  Seq Scan on "TORO2_FLC_HDR" d  (cost=0.00..8188.27 rows=786027 width=37) (actual time=0.097..104.376 rows=775347 loops=1)
Planning time: 24.527 ms
  (slice0)    Executor memory: 426K bytes.
  (slice1)    Executor memory: 123969K bytes avg x 8 workers, 126920K bytes max (seg0).  Work_mem: 48460K bytes max.
Memory used:  126976kB
Optimizer: Postgres query optimizer
Execution time: 6717.806 ms
