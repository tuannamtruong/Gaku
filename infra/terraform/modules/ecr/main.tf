locals {
  names = toset(var.repository_names)

  # One of the two blocks below is always empty, so this collapses to whichever
  # is real and keeps the outputs identical either way.
  repositories = var.create ? {
    for name, repo in aws_ecr_repository.this : name => {
      url  = repo.repository_url
      arn  = repo.arn
      name = repo.name
    }
    } : {
    for name, repo in data.aws_ecr_repository.existing : name => {
      url  = repo.repository_url
      arn  = repo.arn
      name = repo.name
    }
  }
}

resource "aws_ecr_repository" "this" {
  for_each = var.create ? local.names : toset([])

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = each.value
  }
}

data "aws_ecr_repository" "existing" {
  for_each = var.create ? toset([]) : local.names

  name = each.value
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = var.create ? local.names : toset([])

  repository = aws_ecr_repository.this[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.untagged_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the newest ${var.keep_last_images} tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_last_images
        }
        action = { type = "expire" }
      },
    ]
  })
}
