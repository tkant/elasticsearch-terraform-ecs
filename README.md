# Elasticsearch-Terraform-ECS-EFS
A Production ready ECS cluster of elasticsearch 1.7, Use docker on local and use terraform module to deploy on ECS

For local development have a look at this example docker-compose.yml config:
```
elasticsearch:
  build: ./elasticsearch/
  mem_limit: 512m
  ports:
    - "9200:9200"
    - "9300:9300"
  volumes:
    - ./elasticsearch/es_data:/usr/share/elasticsearch/data
```

On AWS I had included terraform code to create:
1. EFS: Used as a persistent storage for our ElasticSearch Cluster
2. ECS: Cluster and Task definition
3. ELB: Internal ELB use with private subnet
4. SG
5. IAM Role

### Change terraform variables before going ahead
Look terraform/es/variables.tf
Change name, image_elasticsearch, vpc_id, etc as per your need. The image name provided is being used by me which is hosted on ECR

## Author
[**Tushar Kant**](http://tusharkant.com) <tushar91delete@gmail.com> 
