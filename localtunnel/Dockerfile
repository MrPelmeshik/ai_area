FROM node:18-alpine

RUN npm install -g localtunnel

COPY start-localtunnel.sh /usr/local/bin/start-localtunnel.sh
RUN chmod +x /usr/local/bin/start-localtunnel.sh

WORKDIR /app

ENTRYPOINT ["/usr/local/bin/start-localtunnel.sh"]

