FROM node:16 as builder

WORKDIR /app
ADD package*.json ./
RUN npm ci --production
ADD . .
ARG backend_url
RUN npm run build

FROM nginx:1
COPY --from=builder /app/build/ /usr/share/nginx/html/
ADD nginx.conf /etc/nginx/conf.d/default.conf
ADD set-backend-url.sh /docker-entrypoint.d/set-backend-url.sh
