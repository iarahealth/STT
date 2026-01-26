from pathlib import Path

import mlflow
import numpy as np


def mlflow_run_required(method):
    """
    Decorator to check if MLflow run is active before calling the method.
    """

    def wrapper(self, *args, **kwargs):
        if self.enabled and mlflow.active_run():
            return method(self, *args, **kwargs)

    return wrapper


class MLflowClient:
    def __init__(self):
        self.enabled = False
        self.run_id = ""
        self.experiment_name = ""
        self.tracking_uri = ""

    def start_run(
        self, mlflow_tracking_uri, mlflow_experiment_name, run_id, monitoring_name
    ):
        """
        Start an MLflow run for experiment tracking.

        Args:
            mlflow_tracking_uri (str): MLflow tracking server URI (e.g., "http://localhost:5000" or file path)
            mlflow_experiment_name (str): Name of the MLflow experiment
            run_id (str): Optional run ID to resume existing run
            monitoring_name (str): Namespace prefix for metrics (e.g., "train" or "test")
        """
        if mlflow_tracking_uri and mlflow_experiment_name:
            try:
                # Set tracking URI
                mlflow.set_tracking_uri(mlflow_tracking_uri)
                self.tracking_uri = mlflow_tracking_uri

                # Set or create experiment
                mlflow.set_experiment(mlflow_experiment_name)
                self.experiment_name = mlflow_experiment_name

                # Start or resume run
                if run_id:
                    # Resume existing run
                    mlflow.start_run(run_id=run_id)
                    self.run_id = run_id
                    print(f"MLflow run resumed with ID: {run_id}")
                else:
                    # Start new run
                    run = mlflow.start_run()
                    self.run_id = run.info.run_id
                    print(f"MLflow run started with ID: {self.run_id}")

                # Store monitoring namespace as tag
                mlflow.set_tag("monitoring_namespace", monitoring_name)

                self.enabled = True
                print(f"MLflow tracking URI: {self.tracking_uri}")
                print(f"MLflow experiment: {self.experiment_name}")

            except Exception as e:
                print(f"Failed to start MLflow run: {e}")
                print("Continuing without MLflow tracking.")
                self.enabled = False
        else:
            print("MLflow run not started (missing tracking_uri or experiment_name).")

    @mlflow_run_required
    def track_artifact(self, name, path):
        """
        Track an artifact (file) within the current MLflow run.
        This logs the artifact to MLflow's artifact store.

        Args:
            name (str): Artifact path/name in MLflow (directory structure).
            path (str): The local path to the artifact file or directory.
        """
        try:
            path_obj = Path(path)
            if path_obj.is_file():
                # Log single file with custom artifact path
                artifact_dir = str(Path(name).parent) if "/" in name else None
                mlflow.log_artifact(str(path), artifact_path=artifact_dir)
            elif path_obj.is_dir():
                # Log entire directory
                mlflow.log_artifacts(str(path), artifact_path=name)
            else:
                print(f"Warning: Artifact path does not exist: {path}")
        except Exception as e:
            print(f"Failed to track artifact {name}: {e}")

    @mlflow_run_required
    def upload_artifact(self, name, path):
        """
        Upload an artifact (file) to the current MLflow run.
        This is an alias for track_artifact for compatibility with Neptune API.

        Args:
            name (str): Artifact path/name in MLflow.
            path (str): The local path to the artifact file.
        """
        self.track_artifact(name, path)

    @mlflow_run_required
    def log_metric(self, name, value, step=None):
        """
        Log a metric value to the current MLflow run.
        Metric values are tracked over time/steps.

        Args:
            name (str): The name of the metric (e.g., "train/loss").
            value: The value of the metric (scalar or array).
            step (int, optional): The step/iteration number for the metric.
        """
        try:
            if isinstance(value, (np.ndarray, list)):
                # For arrays/lists, log each value with incrementing steps
                if isinstance(value, np.ndarray):
                    value = value.tolist()

                base_step = step if step is not None else 0
                for i, val in enumerate(value):
                    if isinstance(val, (int, float, np.integer, np.floating)):
                        mlflow.log_metric(name, float(val), step=base_step + i)
            else:
                # For scalar values
                if isinstance(value, (int, float, np.integer, np.floating)):
                    mlflow.log_metric(name, float(value), step=step)
                else:
                    print(
                        f"Warning: Cannot log non-numeric metric {name}: {type(value)}"
                    )
        except Exception as e:
            print(f"Failed to log metric {name}: {e}")

    @mlflow_run_required
    def log_score(self, name, value):
        """
        Log a score/parameter value to the current MLflow run.
        A "score" is a single value (not tracked over time), logged as a metric without step.
        For configuration values, use log_param instead.

        Args:
            name (str): The name of the score (e.g., "test/wer").
            value: The value of the score.
        """
        try:
            if isinstance(value, (int, float, np.integer, np.floating)):
                # Log as metric without step for final scores
                mlflow.log_metric(name, float(value))
            elif isinstance(value, str):
                # Log as tag for string values
                mlflow.set_tag(name, value)
            else:
                # Try to convert to string for other types
                mlflow.set_tag(name, str(value))
        except Exception as e:
            print(f"Failed to log score {name}: {e}")

    @mlflow_run_required
    def log_param(self, name, value):
        """
        Log a parameter to the current MLflow run.
        Parameters are configuration values (e.g., learning_rate, batch_size).

        Args:
            name (str): The parameter name.
            value: The parameter value.
        """
        try:
            # MLflow params must be strings
            mlflow.log_param(name, value)
        except Exception as e:
            print(f"Failed to log parameter {name}: {e}")

    @mlflow_run_required
    def log_params(self, params_dict):
        """
        Log multiple parameters at once.

        Args:
            params_dict (dict): Dictionary of parameter names and values.
        """
        try:
            mlflow.log_params(params_dict)
        except Exception as e:
            print(f"Failed to log parameters: {e}")

    @mlflow_run_required
    def set_tag(self, name, value):
        """
        Set a tag on the current MLflow run.
        Tags are key-value metadata (e.g., model_version, dataset_name).

        Args:
            name (str): The tag name.
            value: The tag value.
        """
        try:
            mlflow.set_tag(name, str(value))
        except Exception as e:
            print(f"Failed to set tag {name}: {e}")

    @mlflow_run_required
    def stop_run(self):
        """
        Stop the current MLflow run.
        """
        try:
            mlflow.end_run()
            self.enabled = False
            print("MLflow run ended.")
        except Exception as e:
            print(f"Failed to stop MLflow run: {e}")


# Global MLflow client instance
mlflow_client = MLflowClient()
