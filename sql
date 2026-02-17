
[root@rgm-s-dwhapp01 table-dependency-viewer]# DOCKER_BUILDKIT=0 docker compose build --no-cache frontend
Sending build context to Docker daemon  2.888MB
Step 1/11 : FROM node:20-alpine AS build
 ---> 458b0b7c1c60
Step 2/11 : WORKDIR /app
 ---> Running in b5a32dd88b8b
 ---> Removed intermediate container b5a32dd88b8b
 ---> bd9450a09d79
Step 3/11 : COPY package*.json ./
 ---> 10e803ae8818
Step 4/11 : RUN npm ci
 ---> Running in 36116ebebe83
npm error Exit handler never called!
npm error This is an error with npm itself. Please report this error at:
npm error   <https://github.com/npm/cli/issues>
npm error A complete log of this run can be found in: /root/.npm/_logs/2026-02-17T16_32_37_905Z-debug-0.log
 ---> Removed intermediate container 36116ebebe83
 ---> c67774c2a219
Step 5/11 : COPY . .
 ---> 8dcb7a5f3c70
Step 6/11 : RUN npm run build
 ---> Running in 0f160ebb35d8

> table-dependency-viewer@1.0.0 build
> vite build

sh: vite: not found
1 error occurred:
        * Status: The command '/bin/sh -c npm run build' returned a non-zero code: 127, Code: 127

