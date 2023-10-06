import neptune
import numpy as np

from .config import (
    log_info,
)


def neptune_run_required(method):
    """
    Decorator to check if self.nep_run exists before calling the method.
    """

    def wrapper(self, *args, **kwargs):
        if self.nep_run:
            return method(self, *args, **kwargs)

    return wrapper


class NeptuneClient:
    def __init__(self):
        self.nep_run = None
        self.run_id = ""
        self.project = ""
        self.api_token = ""

    def start_run(self, neptune_project, neptune_api_token, run_id, monitoring_name):
        if neptune_project and neptune_api_token:
            run_id = run_id if run_id else None
            monitoring_name = f"monitoring/{monitoring_name}"
            self.nep_run = neptune.init_run(
                project=neptune_project,
                api_token=neptune_api_token,
                with_id=run_id,
                monitoring_namespace=monitoring_name,
            )
            self.run_id = run_id
            self.project = neptune_project
            self.api_token = neptune_api_token
            log_info("Neptune run started.")
            log_info(f"Neptune project {self.project}")
            log_info(f"Neptune API token {self.api_token}")
            log_info(f"Neptune run ID {self.nep_run['sys/id'].fetch()}")
        else:
            log_info("Neptune run not started.")

    @neptune_run_required
    def track_artifact(self, name, path):
        """
        Track an artifact (file) within the current Neptune run.
        Useful if you want to track a file that is not uploaded to Neptune,
        for example, large files.

        Args:
            name (str): Where to store the artifact.
            path (str): The path to the artifact file.

        """
        self.nep_run[name].track_files(path)

    @neptune_run_required
    def upload_artifact(self, name, path):
        """
        Upload an artifact (file) to the current Neptune run.

        Args:
            name (str): Where to store the artifact.
            path (str): The path to the artifact file.

        """
        self.nep_run[name].upload(path)

    @neptune_run_required
    def log_metric(self, name, value):
        """
        Log a metric value to the current Neptune run.
        Metric values are usually values tracked over time.

        Args:
            name (str): The name of the metric.
            value: The value of the metric.

        """
        if isinstance(value, (np.ndarray, list)):
            if isinstance(value, np.ndarray):
                value = value.tolist()
            self.nep_run[name].extend(value)
        else:
            self.nep_run[name].append(value)

    @neptune_run_required
    def log_score(self, name, value):
        """
        Log a score value to the current Neptune run.
        A "score" value can be anything that is not a metric.

        Args:
            name (str): The name of the score.
            value: The value of the score.

        """
        self.nep_run[name] = value

    @neptune_run_required
    def stop_run(self):
        self.nep_run.stop()


neptune_client = NeptuneClient()
