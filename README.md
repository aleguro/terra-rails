This is the IOT sample to create a working env for a RAILS-APP on AWS using

  - PostgresQL
  - Rails 6
  - Ruby 3
  - Redis

# Dependencies

- Terraform (https://developer.hashicorp.com/terraform/downloads)
- Packer
- Gpg

# Init

$ touch ./keys.sh

```
export AWS_ACCESS_KEY_ID=<Your AWS KEY>
export AWS_SECRET_ACCESS_KEY=<You AWS Secret>
```

$ source ./keys.sh

$ make keys.init

# Create infraestrcuture

$ make packer.build

$ make plan 

$ make buid 

$ make output


# WIP: This is a working progress, need to finish structuring the projects