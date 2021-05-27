import os
import functools


def validate_dir(idx):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            if type(idx) == int:
                param = args[idx]
            elif type(idx) == str and idx in kwargs:
                param = kwargs[idx]
            else:
                raise TypeError('Dev Error: validate_dir: invalid argument type passed to decorator')

            if os.path.isdir(param):
                return func(*args, **kwargs)
            else:
                raise NotADirectoryError(f'{func.__name__}: {param}')
        return wrapper
    return decorator


def validate_file(idx):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            if type(idx) == int:
                param = args[idx]
            elif type(idx) == str and idx in kwargs:
                param = kwargs[idx]
            else:
                raise TypeError('Dev Error: validate_file: invalid argument type passed to decorator')

            if os.path.isfile(param):
                return func(*args, **kwargs)
            else:
                raise FileNotFoundError(f'{func.__name__}: {param}')
        return wrapper
    return decorator


def validate_fwhm(idx, size):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            if type(idx) == int:
                param = args[idx]
            elif type(idx) == str and idx in kwargs:
                param = kwargs[idx]
            else:
                raise TypeError('Dev Error: validate_fwhm: invalid argument type passed to decorator')

            if not type(param) == tuple:
                raise TypeError(f'{func.__name__}: FWHM should be a tuple.')

            if len(param) == size:
                return func(*args, **kwargs)
            else:
                raise ValueError(f'{func.__name__}: Incorrect vector size for FWHM: {param}. Vector should be size {size}.')
        return wrapper
    return decorator


def validate_interp(idx, rng):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            if type(idx) == int:
                param = args[idx]
            elif type(idx) == str and idx in kwargs:
                param = kwargs[idx]
            else:
                raise TypeError('Dev Error: validate_interp: invalid argument type passed to decorator.')

            lower, upper = rng
            if not lower < param < upper:
                raise ValueError(f'{func.__name__}: Interpolation value should be in range {rng}.')

            return func(*args, **kwargs)
        return wrapper
    return decorator
