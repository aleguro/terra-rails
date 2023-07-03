#!/bin/bash

init:
	# source ./keys.sh
	gpg --verbose --batch --gen-key unnatennded.key
	gpg --export 07959988387334AF | base64 > gpg.pubkey
	cd ecr ; terraform init
	cd certificates ; terraform init
	cd dev ; terraform init
	cd packer ; packer init
	make ecr.plan ; ecr.build
	make certificates.plan ; certificates.build 
	make ecr.push

packer.build:
	cd packer ; packer build aws.ami.json

plan:
	cd dev ; terraform plan -out dev.plan

build:
	cd dev ; terraform apply "dev.plan"

output:
	cd dev ; terraform output -out dev.plan

destroy:
	cd dev ; terraform destroy

ecr.plan:
	cd ecr ; terraform plan -out ecr.plan

ecr.build:
	cd ecr ; terraform apply "ecr.plan"

ecr.destroy:
	cd ecr ; terraform destroy

ecr.output:
	cd ecr ; terraform output

ecr.push:
	aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${ECR_URL}
	docker build -f ../api/Dockerfile ../api -t api:$(e)
	docker tag api:$(e) ${ECR_URL}/api:$(e)
	docker tag app:$(e) ${ECR_URL}/app:$(e)
	docker tag admin:$(e) ${ECR_URL}/admin:$(e)		
	docker push ${ECR_URL}/api:$(e)
	docker push ${ECR_URL}/app:$(e)
	docker push ${ECR_URL}/admin:$(e)

certificates.plan:
	cd certificates ; terraform plan -out "certificates.plan"

certificates.build:	
	cd certificates ; terraform apply

certificates.output:	
	cd certificates ; terraform output

certificates.destroy:	
	cd certificates ; terraform destroy
