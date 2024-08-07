FROM --platform=linux/x86_64 ruby:3.2.5-alpine3.19 as builder

RUN apk add --update \
    build-base \
    zlib-dev && \
    rm -rf /var/cache/apk/* && \
    gem install bundler jekyll

WORKDIR /app

COPY app .

RUN bundle install

RUN JEKYLL_ENV=production bundle exec jekyll b

FROM nginx:1.24.0-alpine3.17-slim

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
