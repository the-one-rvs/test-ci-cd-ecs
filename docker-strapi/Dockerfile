FROM node:20-bullseye

WORKDIR /app

# Copy package.json first to cache layers
COPY package*.json ./

# Install dependencies cleanly
RUN npm install

# Now copy the full source
COPY . .

# Optional: Rebuild native modules
RUN npm run build

EXPOSE 1337

CMD ["npm", "run", "develop"]
