FROM --platform=linux/x86_64 ruby:3.3.4-alpine AS builder

RUN apk add --update \
    build-base \
    git \
    zlib-dev && \
    rm -rf /var/cache/apk/* && \
    gem install bundler jekyll

WORKDIR /app

COPY app .

RUN bundle config --local force_ruby_platform true

RUN bundle install

RUN JEKYLL_ENV=production bundle exec jekyll b

FROM nginx:1.29.5-alpine-slim

COPY --from=builder /app/_site /usr/share/nginx/html

COPY nginx.conf /etc/nginx/

RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d

RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

CMD ["nginx", "-g", "daemon off;"]
