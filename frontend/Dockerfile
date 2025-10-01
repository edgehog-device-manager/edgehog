# SPDX-FileCopyrightText: 2021-2025 SECO Mind Srl
# SPDX-License-Identifier: Apache-2.0
FROM node:22.4.0 AS builder

WORKDIR /app
ADD package*.json ./
RUN npm ci --omit=dev
ADD . .
ARG backend_url
RUN npm run build

FROM nginx:1
COPY --from=builder /app/build/ /usr/share/nginx/html/
ADD nginx.conf /etc/nginx/conf.d/default.conf
ADD set-backend-url.sh /docker-entrypoint.d/set-backend-url.sh
