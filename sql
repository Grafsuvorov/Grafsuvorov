[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose build --no-cache api
[+] Building 38.6s (7/9)
 => [internal] load build definition from Dockerfile                                                                                 0.0s
 => => transferring dockerfile: 659B                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/python:3.11-slim                                                                  0.0s
 => [internal] load .dockerignore                                                                                                    0.0s
 => => transferring context: 162B                                                                                                    0.0s
 => [1/5] FROM docker.io/library/python:3.11-slim                                                                                    0.0s
 => [internal] load build context                                                                                                    0.0s
 => => transferring context: 1.56kB                                                                                                  0.0s
 => CACHED [2/5] WORKDIR /app/api                                                                                                    0.0s
 => ERROR [3/5] RUN apt-get update && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*                                      38.5s
------
 > [3/5] RUN apt-get update && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*:
#7 31.39 Ign:1 http://deb.debian.org/debian trixie InRelease
#7 31.39 Ign:2 http://deb.debian.org/debian trixie-updates InRelease
#7 31.39 Ign:3 http://deb.debian.org/debian-security trixie-security InRelease
#7 32.39 Ign:3 http://deb.debian.org/debian-security trixie-security InRelease
#7 32.39 Ign:2 http://deb.debian.org/debian trixie-updates InRelease
#7 32.39 Ign:1 http://deb.debian.org/debian trixie InRelease
#7 34.39 Ign:1 http://deb.debian.org/debian trixie InRelease
#7 34.39 Ign:2 http://deb.debian.org/debian trixie-updates InRelease
#7 34.39 Ign:3 http://deb.debian.org/debian-security trixie-security InRelease
#7 38.39 Err:3 http://deb.debian.org/debian-security trixie-security InRelease
#7 38.39   Unable to connect to deb.debian.org:http:
#7 38.39 Err:2 http://deb.debian.org/debian trixie-updates InRelease
#7 38.39   Unable to connect to deb.debian.org:http:
#7 38.39 Err:1 http://deb.debian.org/debian trixie InRelease
#7 38.39   Could not connect to debian.map.fastlydns.net:80 (151.101.66.132), connection timed out Could not connect to debian.map.fastlydns.net:80 (151.101.130.132), connection timed out Could not connect to debian.map.fastlydns.net:80 (151.101.194.132), connection timed out Could not connect to debian.map.fastlydns.net:80 (151.101.2.132), connection timed out Unable to connect to deb.debian.org:http:
#7 38.39   Unable to connect to deb.debian.org:http:
#7 38.39 Reading package lists...
#7 38.40 W: Failed to fetch http://deb.debian.org/debian/dists/trixie/InRelease  Unable to connect to deb.debian.org:http:
#7 38.40 W: Failed to fetch http://deb.debian.org/debian/dists/trixie-updates/InRelease  Unable to connect to deb.debian.org:http:
#7 38.40 W: Failed to fetch http://deb.debian.org/debian-security/dists/trixie-security/InRelease  Unable to connect to deb.debian.org:http:
#7 38.40 W: Some index files failed to download. They have been ignored, or old ones used instead.
#7 38.41 Reading package lists...
#7 38.42 Building dependency tree...
#7 38.42 Reading state information...
#7 38.42 E: Unable to locate package nodejs
------
failed to solve: rpc error: code = Unknown desc = process "/bin/sh -c apt-get update && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*" did not complete successfully: exit code: 100
