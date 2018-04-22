locals {
  defaultLoggingBucket = "${var.s3_fqdn}-bucket-log"
}

resource "aws_s3_bucket" "bucket_log" {
  count  = "${var.loggingBucket == "" ? 1 : 0}"
  bucket = "${local.defaultLoggingBucket}"
  acl    = "log-delivery-write"
  force_destroy = "true"

  tags {
    name = "LoggingBucket"
  }
}

resource "aws_s3_bucket" "this" {
  bucket        = "${var.s3_fqdn}"
  force_destroy = true
  tags          = "${merge(var.tags, map("Name", format("%s", var.s3_fqdn)))}"

  logging {
    target_bucket = "${var.loggingBucket != "" ? var.loggingBucket : local.defaultLoggingBucket}"
    target_prefix = "log/"
  }
}

resource "aws_s3_bucket_policy" "private" {
  count  = "${var.allow_public ? 0 : 1}"
  bucket = "${aws_s3_bucket.this.id}"
  force_destroy = "true"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Action": ["s3:*"],
      "Effect": "Allow",
      "Resource": ["arn:aws:s3:::${var.s3_fqdn}",
                   "arn:aws:s3:::${var.s3_fqdn}/*"],
      "Principal": {
        "AWS": ["${var.role_arn}"]
      }
    }
  ]
}
EOF
}

resource "aws_s3_bucket_policy" "public" {
  count  = "${var.allow_public ? 1 : 0}"
  bucket = "${aws_s3_bucket.this.id}"
  force_destroy = "true"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Action": ["s3:*"],
      "Effect": "Allow",
      "Resource": ["arn:aws:s3:::${var.s3_fqdn}",
                   "arn:aws:s3:::${var.s3_fqdn}/*"],
      "Principal": {
        "AWS": ["${var.role_arn}"]
      }
    },
    {
      "Sid": "",
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": ["arn:aws:s3:::${var.s3_fqdn}",
                   "arn:aws:s3:::${var.s3_fqdn}/*"],
      "Principal": {
        "AWS": "*"
      }
    }
  ]
}
EOF
}

resource "aws_s3_bucket_object" "file" {
  count  = "${length(var.files)}"
  bucket = "${aws_s3_bucket.this.id}"
  key    = "${element(keys(var.files), count.index)}"
  source = "${lookup(var.files, element(keys(var.files), count.index))}"
  etag   = "${md5(file("${lookup(var.files, element(keys(var.files), count.index))}"))}"
}

resource "aws_s3_bucket_object" "base64_file" {
  count          = "${length(var.base64_files)}"
  bucket         = "${aws_s3_bucket.this.id}"
  key            = "${element(keys(var.base64_files), count.index)}"
  content_base64 = "${lookup(var.base64_files, element(keys(var.base64_files), count.index))}"
}
