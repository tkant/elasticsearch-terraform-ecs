module "rdaes" {
  source = "./es"
  region = "eu-west-1"
  vpc_id = "vpc-14bbac70"
  vpc_cidr = "10.0.0.0/23"
  availability_zones = "eu-west-1a,eu-west-1b"
  private_subnet_ids = "subnet-36594752,subnet-0a849b7c"
  key_name = "aws-ireland"
}