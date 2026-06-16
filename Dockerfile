FROM quay.io/astronomer/astro-runtime:12.7.1

RUN python -m venv dbt_venv && . dbt_venv/bin/activate && \
    python -m pip install --no-cache-dir "dbt-bigquery==1.8.3" && deactivate