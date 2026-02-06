@all Важно! Для загрузки объектов в клик, создается отдельный даг для каждого объекта. Все новые даги, по умолчанию появляются в состоянии PAUSED.
Это значит что он не будет работать, пока его не включить. После релиз, необходима проверить и включить новые даги. Для удобства есть Tag - METACLICKHOUSE
Добавил пункт - https://yt.rusal.ru/articles/DWH-A-1009/Instrukciya-po-raskatke-reliza

При выполнении задачи, обязательно создавать ветку в рамках, которой происходит активность.
Пример у меня есть задача - https://yt.rusal.ru/issue/DWH-10012/Ispravlenie-spravochnikov-dictstg.TORO2FLCHDR-dictstg.TORO2EQPHDR.
Значит моя ветка будет называться DWH-10012 . Таким образом, легко находить в рамках чего была активность и разбирать инцидент в случаи падения.

Во всех объектах, у нас присутствуют системные поля:
        dttm_inserted timestamp DEFAULT now() NOT NULL,
	dttm_updated timestamp DEFAULT now() NOT NULL,
	job_name varchar(60) DEFAULT 'airflow'::character varying NOT NULL,
	deleted_flag bool DEFAULT false NOT NULL
Аналитик - может их не указать в своем прототипе. Это необходимо исправлять эта наша зона ответтсвенности, как в таблицах, так и во вью.
