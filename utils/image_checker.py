# import functools




# def check_img(img):
#     def decorator(func):
#         @functools.wraps(func)
#         def wrapper(*args, **kwargs):
#             client = docker.from_env()
#             builder = Builder(client)
#             try:
#                 client.images.get(img)
#             except docker.errors.ImageNotFound:
#                 # strip 'asl/' from img name
#                 method = img.split('/')[-1]
#                 # use dispatcher design pattern to call method
#                 getattr(builder, method)()
#             return func(*args, **kwargs)
#         return wrapper
#     return decorator
