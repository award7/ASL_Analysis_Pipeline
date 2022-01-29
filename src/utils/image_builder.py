import docker
import yaml
import os


def check_img(img, client=None):
    if client is None:
        client = docker.from_env()

    try:
        client.images.get(img)
    except docker.errors.ImageNotFound:
        fname = os.path.join(os.getcwd(), "images.yaml")
        with open(fname, 'r') as f:
            images = yaml.load(f, Loader=yaml.FullLoader)
        if img in images['images']:
            client.images.build(
                path=images['images'][img],
                tag=img,
                rm=True
            )
