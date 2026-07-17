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

FROM nginx:alpine
RUN sed -i 's|pid /var/run/nginx.pid;|pid /tmp/nginx.pid;|' /etc/nginx/nginx.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
