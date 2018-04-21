provider aws {
  alias = "static"
  region = "${var.aws_region}"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}

data template_file "bucket-policy" {
  template = "${file("${path.module}/bucket-policy.json")}"

  vars {
    bucket_name = "${var.domain_name}"
  }
}

resource aws_s3_bucket "static-bucket" {
  provider = "aws.static"
  bucket = "${var.domain_name}"
  acl = "public-read"
  policy = "${data.template_file.bucket-policy.rendered}"

  tags {
    site = "${var.domain_name}"
    owner = "${var.owner}"
  }
}

resource aws_cloudfront_origin_access_identity "static-bucket-origin" {
  comment = "Static bucket origin for ${var.domain_name}"
}

resource aws_cloudfront_distribution "static-site" {
  provider = "aws.static"
  aliases = ["${var.domain_name}"]
  comment = "Static content for ${var.domain_name}"
  default_root_object = "index.html"
  enabled = true
  is_ipv6_enabled = true
  price_class = "${var.cloudfront_price_class}"

  origin {
    domain_name = "${aws_s3_bucket.static-bucket.bucket_domain_name}"
    origin_id = "${var.domain_name}"

    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.static-bucket-origin.cloudfront_access_identity_path}"
    }
  }

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "${var.domain_name}"
    viewer_protocol_policy = "allow-all"
    min_ttl = "${var.cloudfront_min_ttl}"
    default_ttl = "${var.cloudfront_default_ttl}"
    max_ttl = "${var.cloudfront_max_ttl}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  "viewer_certificate" {
    cloudfront_default_certificate = true
  }

  tags {
    site = "${var.domain_name}"
    owner = "${var.owner}"
  }
}

resource "aws_route53_zone" "static-zone" {
  provider = "aws.static"
  name = "${var.domain_name}"

  tags {
    site = "${var.domain_name}"
    owner = "${var.owner}"
  }
}

resource "aws_route53_record" "cloudfront-record" {
  provider = "aws.static"
  name = ""
  type = "A"
  zone_id = "${aws_route53_zone.static-zone.zone_id}"
  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name = "${aws_cloudfront_distribution.static-site.domain_name}"
    zone_id = "${aws_cloudfront_distribution.static-site.hosted_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "secondary-record" {
  provider = "aws.static"
  name = ""
  type = "A"
  zone_id = "${aws_route53_zone.static-zone.zone_id}"
  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name = "${aws_s3_bucket.static-bucket.website_domain}"
    zone_id = "${aws_s3_bucket.static-bucket.hosted_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www-redirect" {
  provider = "aws.static"
  count = "${var.include_www}"
  name = "www"
  type = "CNAME"
  ttl = "${var.dns_ttl}"
  zone_id = "${aws_route53_zone.static-zone.zone_id}"
  records = ["${aws_route53_zone.static-zone.name}"]
}

data template_file "ci-policy" {
  template = "${file("${path.module}/ci-iam-policy.json")}"

  vars {
    bucket_name = "${var.domain_name}"
  }
}

resource "aws_iam_policy" "ci-policy" {
  provider = "aws.static"
  name = "${var.domain_name}-deploy"
  path = "/"
  description = "CI Policy for ${var.domain_name}. Only allows putting objects into the bucket"

  policy = "${data.template_file.ci-policy.rendered}"
}

resource "aws_iam_user" "ci-user" {
  provider = "aws.static"
  name = "${var.domain_name}-ci"
}

resource "aws_iam_user_policy_attachment" "ci-policy-attachment" {
  provider = "aws.static"
  user = "${aws_iam_user.ci-user.name}"
  policy_arn = "${aws_iam_policy.ci-policy.arn}"
}
