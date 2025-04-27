FROM node:18-bullseye AS builder

RUN apt-get update && \
    apt-get install -y python3 make g++ git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

FROM node:18-bullseye

RUN apt-get update && apt-get install -y libvips-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/app

COPY --from=builder /opt/app .

RUN chown -R node:node /opt/app
USER node

EXPOSE 1337

CMD ["npm", "run", "start"]