FROM node:20-alpine AS build

ENV HTTP_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010"
ENV HTTPS_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010"

WORKDIR /app
COPY package*.json ./
RUN npm config set proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010 \
 && npm config set https-proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010 \
 && npm ci --include=dev
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=build /app/dist /app/dist
COPY frontend-server.mjs /app/frontend-server.mjs
EXPOSE 8080
CMD ["node", "/app/frontend-server.mjs"]
