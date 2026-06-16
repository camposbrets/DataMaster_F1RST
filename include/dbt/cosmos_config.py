import os
from cosmos.config import ProfileConfig, ProjectConfig, ExecutionConfig
from pathlib import Path

DBT_CONFIG = ProfileConfig(
    profile_name='capag',
    target_name=os.getenv('DBT_TARGET', 'dev'),
    profiles_yml_filepath=Path('/usr/local/airflow/include/dbt/profiles.yml'),
)

DBT_PROJECT_CONFIG = ProjectConfig(
    dbt_project_path='/usr/local/airflow/include/dbt/',
)

DBT_EXECUTION_CONFIG = ExecutionConfig(
    dbt_executable_path='/usr/local/airflow/dbt_venv/bin/dbt',
)
