import docker


class Builder:

    def __init__(self):
        self.client = docker.from_env()

    def dcm2niix(self):
        # TODO: pull dockerfile from github
        pass


if __name__ == '__main__':
    Builder()
