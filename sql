
[+] Building 461.6s (9/15)
 => [internal] load build definition from Dockerfile                                                                                 0.0s
 => => transferring dockerfile: 1.02kB                                                                                               0.0s
 => [internal] load metadata for docker.io/library/python:3.11-slim                                                                  0.0s
 => [internal] load metadata for docker.io/library/node:20-slim                                                                      0.7s
 => [internal] load .dockerignore                                                                                                    0.0s
 => => transferring context: 162B                                                                                                    0.0s
 => [stage-1 1/8] FROM docker.io/library/python:3.11-slim                                                                            0.0s
 => CACHED [node 1/2] FROM docker.io/library/node:20-slim@sha256:c6585df72c34172bebd8d36abed961e231d7d3b5cee2e01294c4495e8a03f687    0.0s
 => [internal] load build context                                                                                                    0.0s
 => => transferring context: 1.92kB                                                                                                  0.0s
 => CACHED [stage-1 2/8] WORKDIR /app/api                                                                                            0.0s
 => ERROR [node 2/2] RUN npm install -g dagre                                                                                      460.8s
------
 > [node 2/2] RUN npm install -g dagre:
#10 460.7 npm error code ETIMEDOUT
#10 460.7 npm error errno ETIMEDOUT
#10 460.7 npm error network request to https://registry.npmjs.org/dagre failed, reason:
#10 460.7 npm error network This is a problem related to network connectivity.
#10 460.7 npm error network In most cases you are behind a proxy or have bad network settings.
#10 460.7 npm error network
#10 460.7 npm error network If you are behind a proxy, please make sure that the
#10 460.7 npm error network 'proxy' config is set properly.  See: 'npm help config'
#10 460.7 npm error A complete log of this run can be found in: /root/.npm/_logs/2026-02-18T16_29_40_045Z-debug-0.log
------
failed to solve: rpc error: code = Unknown desc = process "/bin/sh -c npm install -g dagre" did not complete successfully: exit code: 1
