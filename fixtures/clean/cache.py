import hashlib


def cache_key(payload: bytes) -> str:
    # preflightkit-ignore: a cache key, not a security use of MD5
    return hashlib.md5(payload).hexdigest()
