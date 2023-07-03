#!/bin/bash
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${EcrHost}
docker pull ${EcrHost}/api:${Environment}  

echo 'docker rmi $(docker images -f "dangling=true" -q) --force 2> /dev/null
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${EcrHost}
docker pull ${EcrHost}/api:${Environment}  
docker-compose -f docker-compose.yml run api rake db:migrate
docker-compose up -d' > deploy.api.sh

echo '  
version: "3"
networks:
  api-network:
    driver: bridge
    ipam:
      config:
        - subnet: 192.167.0.0/25
services:     
  redis:
    image: "redis:alpine"
    ports:
      - "6379:6379"
    container_name: redisdbr 
    networks:
      - api-network
  postgresql:
    container_name: postgresql
    image: "postgres:11"
    networks:
      - api-network    
    ports:
      - '5432:5432'
    volumes:
      - 'postgresql-data:/var/lib/postgresql/data'
    environment:
      - POSTGRESQL_USERNAME=postgres
      - POSTGRESQL_PASSWORD=postgres
      - POSTGRESQL_DATABASE=demo      
      - ALLOW_EMPTY_PASSWORD=yes
      - ALLOW_IP_RANGE=0.0.0.0/0
      - POSTGRES_HOST_AUTH_METHOD=trust
      - LISTEN_ADDRESSES='*'
    deploy:
      resources:
        limits:
          memory: '2gb'        
  api:
    image: ${EcrHost}/api:${Environment}
    container_name: api
    command: /bin/sh -c "rm -f /app/tmp/pids/server.pid && foreman start -f Procfile.development"
    ports:
      - "3000:3000"
    networks:
      - api-network
    logging:
      driver: awslogs
      options:
        awslogs-region: us-west-2
        awslogs-group: ${ApiCloudWatchGroup}
        awslogs-stream: api 
    environment:
      SMTP_USER: ${SmtpUser}
      SMTP_PASSWORD: ${SmtpPassword}
      RAILS_ENV: staging
      RAILS_LOG_TO_STDOUT: 1     
      REDIS_HOST: redisdbr
      REDIS_URL: redis://redisdbr:6379
      PG_PORT: 5432
      PG_HOST: postgresql
      DATABASE_URL: postgres://postgres:postgres@postgresql:5432/database_development
      DOCKER: 1
volumes:
  postgresql-data:
    driver: local
  data:
    driver: local  
  edata:
    driver: local' >> docker-compose.yml

chmod +x deploy.api.sh
cp docker-compose.yml /home/ec2-user/
cp deploy.api.sh      /home/ec2-user/
