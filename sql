FROM node:20-alpine AS build
  WORKDIR /app
  COPY package*.json ./
  RUN npm i -g npm@9
  RUN npm ci --include=dev
  COPY . .
  RUN npm run build
