# Self-dogfood through an integration branch

The Personal Symphony Product Repository can also act as a Workspace Repository for its own work, but allowing automated Task Branch integration directly into `main` would bypass normal Product Repository review and release safeguards. Self-dogfooding runs should start from a dedicated non-trunk Loop-Start Branch, such as `symphony/dogfood`, fast-forward merge completed Task Branches into that branch, and open a Batch Pull Request to `main` only after Orchestration Idle.
