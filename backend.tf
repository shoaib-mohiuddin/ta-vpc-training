terraform {
    backend "s3" {
        bucket = "talent-academy-lab-shoaib-tfstates-166916347510"
        key = "talent-academy/vpc/terraform.tfstates"
        region = "eu-west-1"
        # dynamodb_table = "terraform-lock" # Deprecated, use native state locking with S3
        use_lockfile = true # S3 native state locking
    }
}