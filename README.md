# Hydra - Phishing Defense + Autoscaling Demo (safe demo mode)

This repository contains a local demo for the Hydra project:
- A minimal static site (services/static-site)
- A safe, controlled load test using k6 (services/load-tester)
- Kubernetes manifests for HPA demo (infra/k8s)

**Important**: This repo uses *controlled load testing* for demos. Do NOT use it to target infrastructure you do not own or have explicit authorization to test.

See `utils/README_USAGE.md` for usage instructions.
