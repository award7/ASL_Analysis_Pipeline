import docker


class Builder:

    def __init__(self, client: object = None):
        """Docker image builder for various ASL Processing software"""
        if client is None:
            client = docker.from_env()
        self.client = client

    def afni(self):
        path = "https://raw.githubusercontent.com/award7/ASL_Analysis_Pipeline/v2/docker/afni/Dockerfile"
        tag = "asl/afni"
        self._build(path, tag)

    def dcm2niix(self):
        # TODO: move to yaml to avoid hardcoding here?
        path = "https://raw.githubusercontent.com/award7/ASL_Analysis_Pipeline/v2/docker/dcm2niix/Dockerfile"
        tag = "asl/dcm2niix"
        self._build(path, tag)

    def fsl(self):
        path = "https://raw.githubusercontent.com/award7/ASL_Analysis_Pipeline/v2/docker/fsl/Dockerfile"
        tag = "asl/fsl"
        self._build(path, tag)

    def spm(self):
        path = "https://raw.githubusercontent.com/award7/ASL_Analysis_Pipeline/v2/docker/spm/Dockerfile"
        tag = "asl/spm"
        self._build(path, tag)

    def _pull(self, repo: str, tag: str) -> None:
        self.client.images.pull(
            repository=repo
        )

    def _build(self, path: str, tag: str) -> None:
        self.client.images.build(
            path=path,
            tag=tag,
            rm=True
        )
