locals {
  cloudfront_custom_header_name = "X-CloudFront-Secret"
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = ""
  price_class         = "PriceClass_200"

  aliases = [var.domain_name]

  origin {
    # CloudFront はオリジンに IP アドレスを指定できないため、
    # Elastic IP の AWS 自動割り当て DNS ホスト名を使用する
    # 形式: ec2-<ip-with-dashes>.ap-northeast-1.compute.amazonaws.com
    domain_name = "ec2-${replace(aws_eip.main.public_ip, ".", "-")}.ap-northeast-1.compute.amazonaws.com"
    origin_id   = "EC2-ECS"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # カスタムヘッダーで EC2 オリジンを保護 (EC2 SG の prefix list 制限が主な保護)
    custom_header {
      name  = local.cloudfront_custom_header_name
      value = var.cloudfront_secret_header_value
    }
  }

  default_cache_behavior {
    target_origin_id       = "EC2-ECS"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]

    # キャッシュ無効 (API サーバーのため)
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"   # CachingDisabled (マネージドポリシー)
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"   # AllViewerExceptHostHeader (マネージドポリシー)
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.main.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${var.app_name}-cloudfront"
  }
}
