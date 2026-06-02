# ML v2 — Future Model Migration

This directory is reserved for Sprint 3 ML implementation.

## Planned Models
- Random Forest Classifier for distraction risk prediction
- K-Means Clustering for user behavior segmentation
- LSTM for sequential distraction pattern detection

## Migration Plan
1. Collect 500+ real sessions from beta users
2. Label outcomes (nudge effective / not effective)
3. Train Random Forest on event features
4. A/B test against rule engine
5. Replace rule_engine.py calls with ml_v2/predictor.py

## Data Schema for Training
See docs/api_contracts.md for event schema used as ML feature input.

DO NOT add any Python files here until Sprint 3.
