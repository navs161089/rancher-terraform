# bootstrap

One-time, run-once-by-hand infrastructure that must exist *before* any environment can use a remote backend — e.g. the S3 bucket + DynamoDB lock table (or equivalent) that will eventually back `environments/*` state once we migrate off the local backend.

Empty for now: the `local` environment uses the `local` backend (see `environments/local/backend.tf`), so there is nothing to bootstrap yet.
