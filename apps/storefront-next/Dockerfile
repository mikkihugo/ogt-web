FROM node:20-alpine

WORKDIR /app
COPY package.json .
# COPY package-lock.json . 
# RUN npm install

# We just copy source and start for now since we are in a monorepo migration with no lockfile
COPY . .

CMD ["npm", "run", "dev"] 
