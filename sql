Gather Motion 6:1  (slice3; segments: 6)  (cost=27543.97..27685.89 rows=20 width=618)
  ->  Subquery Scan on new_only  (cost=27543.97..27685.89 rows=4 width=618)
        ->  Hash Anti Join  (cost=27543.97..27684.59 rows=4 width=618)
              Hash Cond: (("INPUT_DATA_FROM_SAPXI_IN".uuid)::text = (d.uuid)::text)
              ->  Redistribute Motion 6:6  (slice1; segments: 6)  (cost=0.00..88.73 rows=370 width=618)
                    Hash Key: "INPUT_DATA_FROM_SAPXI_IN".uuid
                    ->  Result  (cost=0.00..318.49 rows=370 width=864)
                          ->  Seq Scan on "INPUT_DATA_FROM_SAPXI_IN"  (cost=0.00..318.49 rows=370 width=864)
                                Filter: ((flow_id)::text = 'SI_TechPlaceReplicate_AI'::text)
              ->  Hash  (cost=19561.33..19561.33 rows=106436 width=37)
                    ->  Redistribute Motion 6:6  (slice2; segments: 6)  (cost=0.00..19561.33 rows=106436 width=37)
                          Hash Key: d.uuid
                          ->  Seq Scan on "TORO2_FLC_HDR" d  (cost=0.00..6789.11 rows=106436 width=37)
Optimizer: Postgres query optimizer


Gather Motion 6:1  (slice2; segments: 6)  (cost=106871.71..118327.56 rows=1929 width=864)
  ->  Subquery Scan on items  (cost=106871.71..118327.56 rows=322 width=864)
        ->  Result  (cost=106871.71..118202.21 rows=322 width=864)
              ->  Hash Left Anti Semi (Not-In) Join  (cost=106871.71..118202.21 rows=322 width=864)
                    Hash Cond: (("INPUT_DATA_FROM_SAPXI_IN".uuid)::text = ("TORO2_FLC_HDR".uuid)::text)
                    ->  Seq Scan on "INPUT_DATA_FROM_SAPXI_IN"  (cost=0.00..307.40 rows=4 width=864)
                          Filter: ((flow_id)::text = 'SI_TechPlaceReplicate_AI'::text)
                    ->  Hash  (cost=51491.88..51491.88 rows=638611 width=37)
                          ->  Broadcast Motion 6:6  (slice1; segments: 6)  (cost=0.00..51491.88 rows=638611 width=37)
                                ->  Seq Scan on "TORO2_FLC_HDR"  (cost=0.00..6789.11 rows=106436 width=37)
Optimizer: Postgres query optimizer
