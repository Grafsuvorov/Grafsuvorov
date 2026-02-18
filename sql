[root@rgm-s-dwhapp01 table-dependency-viewer]# docker run --rm \
>     -e HTTP_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010" \
>     -e HTTPS_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010" \
>     -v "$PWD":/app -w /app \
>     node:20-alpine sh -lc \
>     "npm config set proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010 && \
>      npm config set https-proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010 && \
>      npm install react-router-dom"

added 7 packages, and audited 130 packages in 7s

12 packages are looking for funding
  run `npm fund` for details

2 moderate severity vulnerabilities

To address all issues, run:
  npm audit fix

Run `npm audit` for details.
[root@rgm-s-dwhapp01 table-dependency-viewer]# DOCKER_BUILDKIT=0 docker compose build --no-cache frontend
Sending build context to Docker daemon  2.889MB
Step 1/14 : FROM node:20-alpine AS build
 ---> 458b0b7c1c60
Step 2/14 : ENV HTTP_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010"
 ---> Running in 22de5387ac1b
 ---> Removed intermediate container 22de5387ac1b
 ---> d61ecd05ddca
Step 3/14 : WORKDIR /app
 ---> Running in fcd24e4388e2
 ---> Removed intermediate container fcd24e4388e2
 ---> 26fe67ebb9cc
Step 4/14 : COPY package*.json ./
 ---> 23446fd96520
Step 5/14 : RUN npm config set proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010
 ---> Running in c552d1410afa
 ---> Removed intermediate container c552d1410afa
 ---> a37ea711f161
Step 6/14 : RUN npm i -g npm@9
 ---> Running in 2adb4bd9ac72

removed 13 packages, and changed 86 packages in 13s

27 packages are looking for funding
  run `npm fund` for details
 ---> Removed intermediate container 2adb4bd9ac72
 ---> 37ed596df92f
Step 7/14 : RUN npm ci --include=dev
 ---> Running in 1df27ed51dad

added 127 packages, and audited 128 packages in 6s

12 packages are looking for funding
  run `npm fund` for details

2 moderate severity vulnerabilities

To address all issues, run:
  npm audit fix

Run `npm audit` for details.
 ---> Removed intermediate container 1df27ed51dad
 ---> 5c45599200e2
Step 8/14 : COPY . .
 ---> 9626ca76895c
Step 9/14 : RUN npm run build
 ---> Running in 9e8ce9f0f900

> table-dependency-viewer@1.0.0 build
> vite build

vite v7.0.5 building for production...
transforming...
✓ 35 modules transformed.
✗ Build failed in 329ms
error during build:
[vite]: Rollup failed to resolve import "recharts" from "/app/src/components/IncidentsPage.jsx".
This is most likely unintended because it can break your application at runtime.
If you do want to externalize this module explicitly add it to
`build.rollupOptions.external`
    at viteLog (file:///app/node_modules/vite/dist/node/chunks/dep-Bg4HVnP5.js:34221:57)
    at file:///app/node_modules/vite/dist/node/chunks/dep-Bg4HVnP5.js:34259:73
    at onwarn (file:///app/node_modules/@vitejs/plugin-react/dist/index.js:90:7)
    at file:///app/node_modules/vite/dist/node/chunks/dep-Bg4HVnP5.js:34259:28
    at onRollupLog (file:///app/node_modules/vite/dist/node/chunks/dep-Bg4HVnP5.js:34254:3)
    at onLog (file:///app/node_modules/vite/dist/node/chunks/dep-Bg4HVnP5.js:34042:4)
    at file:///app/node_modules/rollup/dist/es/shared/node-entry.js:20818:32
    at Object.logger [as onLog] (file:///app/node_modules/rollup/dist/es/shared/node-entry.js:22698:9)
    at ModuleLoader.handleInvalidResolvedId (file:///app/node_modules/rollup/dist/es/shared/node-entry.js:21444:26)
    at file:///app/node_modules/rollup/dist/es/shared/node-entry.js:21402:26
1 error occurred:
        * Status: The command '/bin/sh -c npm run build' returned a non-zero code: 1, Code: 1
