[root@rgm-s-dwhapp01 table-dependency-viewer]# DOCKER_BUILDKIT=0 docker compose build --no-cache frontend
Sending build context to Docker daemon  2.888MB
Step 1/11 : FROM node:20-alpine AS build
20-alpine: Pulling from library/node
589002ba0eae: Already exists
ad6d96c196e3: Already exists
eb87f4721c91: Already exists
e31b20165522: Already exists
Digest: sha256:09e2b3d9726018aecf269bd35325f46bf75046a643a66d28360ec71132750ec8
Status: Downloaded newer image for node:20-alpine
 ---> 458b0b7c1c60
Step 2/11 : WORKDIR /app
 ---> Running in 24a766e03b35
 ---> Removed intermediate container 24a766e03b35
 ---> a292ccc82a23
Step 3/11 : COPY package*.json ./
 ---> 731856bfdb79
Step 4/11 : RUN npm ci
 ---> Running in 6376c16ba737
npm error Exit handler never called!
npm error This is an error with npm itself. Please report this error at:
npm error   <https://github.com/npm/cli/issues>
npm error A complete log of this run can be found in: /root/.npm/_logs/2026-02-17T15_50_17_952Z-debug-0.log
 ---> Removed intermediate container 6376c16ba737
 ---> 458895fc8c07
Step 5/11 : COPY . .
 ---> 74d27b871b30
Step 6/11 : RUN npm run build
 ---> Running in 7533797c0c7b

> table-dependency-viewer@1.0.0 build
> vite build

sh: vite: not found
1 error occurred:
        * Status: The command '/bin/sh -c npm run build' returned a non-zero code: 127, Code: 127
