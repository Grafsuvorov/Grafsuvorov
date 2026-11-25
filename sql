 => [table-dependency-viewer_api stage-1  9/10] RUN HTTP_PROXY= HTTPS_PROXY= http_proxy= https_proxy=   pip install --index-url=https  61.3s
 => ERROR [table-dependency-viewer_api stage-1 10/10] RUN apt-get update     && apt-get install -y --no-install-recommends openssh-cli  9.6s
------
 > [table-dependency-viewer_api stage-1 10/10] RUN apt-get update     && apt-get install -y --no-install-recommends openssh-client sshpass     && rm -rf /var/lib/apt/lists/*:
#19 0.565 Get:1 http://deb.debian.org/debian trixie InRelease [140 kB]
#19 0.565 Ign:1 http://deb.debian.org/debian trixie InRelease
#19 0.714 Get:2 http://deb.debian.org/debian trixie-updates InRelease [47.3 kB]
#19 0.714 Ign:2 http://deb.debian.org/debian trixie-updates InRelease
#19 0.907 Get:3 http://deb.debian.org/debian-security trixie-security InRelease [43.4 kB]
#19 0.907 Ign:3 http://deb.debian.org/debian-security trixie-security InRelease
#19 2.057 Get:3 http://deb.debian.org/debian-security trixie-security InRelease [43.4 kB]
#19 2.057 Ign:3 http://deb.debian.org/debian-security trixie-security InRelease
#19 2.206 Get:2 http://deb.debian.org/debian trixie-updates InRelease [47.3 kB]
#19 2.206 Ign:2 http://deb.debian.org/debian trixie-updates InRelease
#19 2.354 Get:1 http://deb.debian.org/debian trixie InRelease [140 kB]
#19 2.354 Ign:1 http://deb.debian.org/debian trixie InRelease
#19 4.507 Get:1 http://deb.debian.org/debian trixie InRelease [140 kB]
#19 4.507 Ign:1 http://deb.debian.org/debian trixie InRelease
#19 4.656 Get:2 http://deb.debian.org/debian trixie-updates InRelease [47.3 kB]
#19 4.656 Ign:2 http://deb.debian.org/debian trixie-updates InRelease
#19 4.828 Get:3 http://deb.debian.org/debian-security trixie-security InRelease [43.4 kB]
#19 4.828 Ign:3 http://deb.debian.org/debian-security trixie-security InRelease
#19 8.978 Get:3 http://deb.debian.org/debian-security trixie-security InRelease [43.4 kB]
#19 8.978 Err:3 http://deb.debian.org/debian-security trixie-security InRelease
#19 8.978   Error writing to file - write (28: No space left on device) [IP: 10.66.228.23 1010]
#19 9.127 Get:2 http://deb.debian.org/debian trixie-updates InRelease [47.3 kB]
#19 9.128 Err:2 http://deb.debian.org/debian trixie-updates InRelease
#19 9.128   Error writing to file - write (28: No space left on device) [IP: 10.66.228.23 1010]
#19 9.295 Get:1 http://deb.debian.org/debian trixie InRelease [140 kB]
#19 9.295 Err:1 http://deb.debian.org/debian trixie InRelease
#19 9.295   Error writing to file - write (28: No space left on device) [IP: 10.66.228.23 1010]
#19 9.298 Reading package lists...
#19 9.306 W: Failed to fetch http://deb.debian.org/debian/dists/trixie/InRelease  Error writing to file - write (28: No space left on device) [IP: 10.66.228.23 1010]
#19 9.306 W: Failed to fetch http://deb.debian.org/debian/dists/trixie-updates/InRelease  Error writing to file - write (28: No space left on device) [IP: 10.66.228.23 1010]
#19 9.306 W: Failed to fetch http://deb.debian.org/debian-security/dists/trixie-security/InRelease  Error writing to file - write (28: No space left on device) [IP: 10.66.228.23 1010]
#19 9.306 W: Some index files failed to download. They have been ignored, or old ones used instead.
#19 9.314 Reading package lists...
#19 9.321 Building dependency tree...
#19 9.321 Reading state information...
#19 9.322 E: Unable to locate package sshpass
------
failed to solve: rpc error: code = Unknown desc = process "/bin/sh -c apt-get update     && apt-get install -y --no-install-recommends openssh-client sshpass     && rm -rf /var/lib/apt/lists/*" did not complete successfully: exit code: 100
https://yt.rusal.ru/issue/SDS-471/OHD-Novye-tablicy-dorabotka-vitrin

Проект

ОХД - Общее Хранилище Данных (Данные партнеров)
User avatar
Тип карточки

Release Slot⁠
R
Состояние

Завершена
З
Исполнитель

Kitaev Stanislav
User avatar
Команда (Подсистема)

DE (Data Engineer)⁠
D
Направление

Нет: направление
Дашборд КХД/Направление

Релиз
Дежурный аналитик

Нет: дежурный аналитик
Номер релиза КХД

Нет: номер релиза кхд
Фактическая дата релиза КХД
Нет: фактическая дата релиза кхд
Экономия за счет ИИ

?
Доски

Нет видимых досок
  
OHD_YOUTRACK_PROJECT=ОХД - Общее Хранилище Данных (Данные партнеров)
OHD_YOUTRACK_PROJECT_ID=
OHD_YOUTRACK_QUEUE=
OHD_YOUTRACK_DIRECTION_FIELD_NAME=Дашборд КХД/Направление
