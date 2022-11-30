FROM ubuntu AS build
RUN apt update
RUN apt install -y hugo
WORKDIR /hugo
COPY . .
ARG url=https://harry.technology/
RUN hugo --baseURL=$url

FROM nginx
COPY --from=build /hugo/public /var/www
COPY ./nginx.conf /etc/nginx/nginx.conf