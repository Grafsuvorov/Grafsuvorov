2. Проверь права по OID роли
У тебя:
SELECT2. Проверь права по OID ролиSELECT
    oid,
    rolname
FROM pg_roles
WHERE rolname = 'логин_сотрудника';


У сотрудника:
SELECT
    oid,
    rolname
FROM pg_roles
WHERE rolname = current_user;


Сравните OID.

Если они разные, это не одна и та же роль, даже если имена похожи.
3. Самая полезная проверка — сравнить права на один объект для двух ролей
Пусть сотрудник выполнит:
SELECT
    current_user,
    session_user,
    has_table_privilege(
        current_user,
        'dm.customer',
        'SELECT'
    ) AS current_user_access,
    has_table_privilege(
        session_user,
        'dm.customer',
        'SELECT'
    ) AS session_user_access,
    has_table_privilege(
        'логин_сотрудника',
        'dm.customer',
        'SELECT'
    ) AS explicit_user_access;


Если current_user_access = false, а explicit_user_access = true, значит фактическая текущая роль отличается от той, которой выдали права.

Если все три false, но у тебя для того же логина true, нужно сравнивать объекты и кластеры.
4. Отдельно проверь, не пересоздаётся ли таблица
Если таблица создаётся не технической учёткой, это само по себе не мешает доступу.

Но если процесс загрузки выполняет:
DROP TABLE dm.customer;

CREATE TABLE dm.customer (...);


то новая таблица получает новый OID и собственный набор прав.

При этом ранее выданный GRANT на старую таблицу не сохраняется автоматически.

Ещё одна проверка, которую я бы сделал
Попроси сотрудника выполнить:
SELECT
    current_user,
    session_user,
    c.oid,
    c.relacl,
    has_table_privilege(c.oid, 'SELECT') AS access_by_oid
FROM pg_class c
WHERE c.oid = 'dm.customer'::regclass;


Это исключит неоднозначность обращения к таблице по имени.

И скажи мне одну вещь: какая у вас версия Greenplum — GP6 или GP7?

Это важно, потому что если у вас GP6, а права действительно видны в relacl, но не работают, я бы дополнительно проверил состояние системных каталогов и возможные особенности их синхронизации. Пока менять владельца таблицы или выдавать права на всю схему не нужно.
У тебя:
SELECT
    oid,
    rolname
FROM pg_roles
WHERE rolname = 'логин_сотрудника';


У сотрудника:
SELECT
    oid,
    rolname
FROM pg_roles
WHERE rolname = current_user;


Сравните OID.

Если они разные, это не одна и та же роль, даже если имена похожи.
3. Самая полезная проверка — сравнить права на один объект для двух ролей
Пусть сотрудник выполнит:
SELECT
    current_user,
    session_user,
    has_table_privilege(
        current_user,
        'dm.customer',
        'SELECT'
    ) AS current_user_access,
    has_table_privilege(
        session_user,
        'dm.customer',
        'SELECT'
    ) AS session_user_access,
    has_table_privilege(
        'логин_сотрудника',
        'dm.customer',
        'SELECT'
    ) AS explicit_user_access;


Если current_user_access = false, а explicit_user_access = true, значит фактическая текущая роль отличается от той, которой выдали права.

Если все три false, но у тебя для того же логина true, нужно сравнивать объекты и кластеры.
4. Отдельно проверь, не пересоздаётся ли таблица
Если таблица создаётся не технической учёткой, это само по себе не мешает доступу.

Но если процесс загрузки выполняет:
DROP TABLE dm.customer;

CREATE TABLE dm.customer (...);


то новая таблица получает новый OID и собственный набор прав.

При этом ранее выданный GRANT на старую таблицу не сохраняется автоматически.

Ещё одна проверка, которую я бы сделал
Попроси сотрудника выполнить:
SELECT
    current_user,
    session_user,
    c.oid,
    c.relacl,
    has_table_privilege(c.oid, 'SELECT') AS access_by_oid
FROM pg_class c
WHERE c.oid = 'dm.customer'::regclass;


Это исключит неоднозначность обращения к таблице по имени.

И скажи мне одну вещь: какая у вас версия Greenplum — GP6 или GP7?

Это важно, потому что если у вас GP6, а права действительно видны в relacl, но не работают, я бы дополнительно проверил состояние системных каталогов и возможные особенности их синхронизации. Пока менять владельца таблицы или выдавать права на всю схему не нужно.
    oid,
    rolname
FROM pg_roles
WHERE rolname = 'логин_сотрудника';


У сотрудника:
SELECT
    oid,
    rolname
FROM pg_roles
WHERE rolname = current_user;


Сравните OID.

Если они разные, это не одна и та же роль, даже если имена похожи.
3. Самая полезная проверка — сравнить права на один объект для двух ролей
Пусть сотрудник выполнит:
SELECT
    current_user,
    session_user,
    has_table_privilege(
        current_user,
        'dm.customer',
        'SELECT'
    ) AS current_user_access,
    has_table_privilege(
        session_user,
        'dm.customer',
        'SELECT'
    ) AS session_user_access,
    has_table_privilege(
        'логин_сотрудника',
        'dm.customer',
        'SELECT'
    ) AS explicit_user_access;


Если current_user_access = false, а explicit_user_access = true, значит фактическая текущая роль отличается от той, которой выдали права.

Если все три false, но у тебя для того же логина true, нужно сравнивать объекты и кластеры.
4. Отдельно проверь, не пересоздаётся ли таблица
Если таблица создаётся не технической учёткой, это само по себе не мешает доступу.

Но если процесс загрузки выполняет:
DROP TABLE dm.customer;

CREATE TABLE dm.customer (...);


то новая таблица получает новый OID и собственный набор прав.

При этом ранее выданный GRANT на старую таблицу не сохраняется автоматически.

Ещё одна проверка, которую я бы сделал
Попроси сотрудника выполнить:
SELECT
    current_user,
    session_user,
    c.oid,
    c.relacl,
    has_table_privilege(c.oid, 'SELECT') AS access_by_oid
FROM pg_class c
WHERE c.oid = 'dm.customer'::regclass;


Это исключит неоднозначность обращения к таблице по имени.

И скажи мне одну вещь: какая у вас версия Greenplum — GP6 или GP7?

Это важно, потому что если у вас GP6, а права действительно видны в relacl, но не работают, я бы дополнительно проверил состояние системных каталогов и возможные особенности их синхронизации. Пока менять владельца таблицы или выдавать права на всю схему не нужно.
