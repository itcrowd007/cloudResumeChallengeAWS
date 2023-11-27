locals {
  s3_origin_id = "OriginIDFor_${aws_s3_bucket.website_bucket.bucket}_Bucket"
}


resource "aws_cloudfront_origin_access_identity" "default" {
  comment = "AWS cloudfront identity for S3"
}


resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "OAC ${aws_s3_bucket.website_bucket.id}"
  description                       = "OAC ${aws_s3_bucket.website_bucket.id} policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Static website hosting for: ${aws_s3_bucket.website_bucket.id}"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    
    
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = {
    Domain = var.user_domain
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "terraform_data" "invalidate_cache" {
  for_each = fileset("${var.public_path}/", "*.{jpg,png,gig,css,html,js}")
  triggers_replace = {
    for file in fileset("${var.public_path}/", "*.{jpg,png,gig,css,html,js}") : file => md5(file("${var.public_path}/${file}"))
    }
  #triggers_replace = [each.value]
  #triggers_replace = terraform_data.md5_hash_public.triggers_replace
 
  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.s3_distribution.id} --paths '/*'"
  }
}