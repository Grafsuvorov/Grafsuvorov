
[root@rgm-s-dwhapp01 table-dependency-viewer]# DOCKER_BUILDKIT=0 docker compose build --no-cache frontend
Sending build context to Docker daemon  2.888MB
Step 1/12 : FROM node:20-alpine AS build
 ---> 458b0b7c1c60
Step 2/12 : WORKDIR /app
 ---> Running in 4b995bbdbb57
 ---> Removed intermediate container 4b995bbdbb57
 ---> 4f9b7c7d0dad
Step 3/12 : COPY package*.json ./
 ---> b93278b674a5
Step 4/12 : RUN npm i -g npm@9
 ---> Running in 74e005a2938e
npm error code ETIMEDOUT
npm error errno ETIMEDOUT
npm error network request to https://registry.npmjs.org/npm failed, reason:
npm error network This is a problem related to network connectivity.
npm error network In most cases you are behind a proxy or have bad network settings.
npm error network
npm error network If you are behind a proxy, please make sure that the
npm error network 'proxy' config is set properly.  See: 'npm help config'
npm error A complete log of this run can be found in: /root/.npm/_logs/2026-02-17T16_36_43_915Z-debug-0.log
1 error occurred:
        * Status: The command '/bin/sh -c npm i -g npm@9' returned a non-zero code: 1, Code: 1

