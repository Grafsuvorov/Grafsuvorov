
[root@rgm-s-dwhapp01 table-dependency-viewer]# DOCKER_BUILDKIT=0 docker compose build --no-cache frontend
Sending build context to Docker daemon  2.888MB
Step 1/14 : FROM node:20-alpine AS build
 ---> 458b0b7c1c60
Step 2/14 : ENV HTTP_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010"
 ---> Running in 8925159641a5
 ---> Removed intermediate container 8925159641a5
 ---> 644a752c5e4f
Step 3/14 : WORKDIR /app
 ---> Running in c471b5687fdc
 ---> Removed intermediate container c471b5687fdc
 ---> 711815a3ebfa
Step 4/14 : COPY package*.json ./
 ---> 6a245c3a1c3a
Step 5/14 : RUN npm config set proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010
 ---> Running in 424d5b70a938
 ---> Removed intermediate container 424d5b70a938
 ---> 91394d699de5
Step 6/14 : RUN npm i -g npm@9
 ---> Running in 2fd463a4f672

removed 13 packages, and changed 86 packages in 11s

27 packages are looking for funding
  run `npm fund` for details
 ---> Removed intermediate container 2fd463a4f672
 ---> f89763f4a886
Step 7/14 : RUN npm ci --include=dev
 ---> Running in 35aa516d97f9

added 123 packages, and audited 124 packages in 4s

11 packages are looking for funding
  run `npm fund` for details

2 moderate severity vulnerabilities

To address all issues, run:
  npm audit fix

Run `npm audit` for details.
 ---> Removed intermediate container 35aa516d97f9
 ---> 2f70e9dbde51
Step 8/14 : COPY . .
 ---> 350ddbcbc58b
Step 9/14 : RUN npm run build
 ---> Running in 13411aa798c1

> table-dependency-viewer@1.0.0 build
> vite build

vite v7.0.5 building for production...
transforming...
✓ 2 modules transformed.
✗ Build failed in 49ms
error during build:
[vite]: Rollup failed to resolve import "react-router-dom" from "/app/src/main.jsx".
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
