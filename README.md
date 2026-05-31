# Terraform AWS S3 Backend

This repository creates an S3 bucket and DynamoDB table to serve as a **remote backend** for storing Terraform state files.

## Purpose

Terraform state files (`.tfstate`) are critical for tracking your infrastructure. Storing them locally on a team member's machine or in Git can lead to:

- **State conflicts** when multiple people run Terraform simultaneously
- **Sensitive data exposure** (state files often contain secrets)
- **Accidental deletion** or loss of state information

This module solves these problems by creating a dedicated S3 bucket with DynamoDB locking to serve as a **remote backend** for all your Terraform projects.

## What This Repository Creates

| Resource | Purpose |
|----------|---------|
| **S3 Bucket** | Centralized, encrypted storage for Terraform state files |
| **DynamoDB Table** | State locking to prevent concurrent modifications |
| **Bucket Versioning** | Enables state recovery from accidental changes |
| **Server-Side Encryption (SSE)** | Encrypts state files at rest |
| **Public Access Block** | Prevents accidental public exposure of state files |

