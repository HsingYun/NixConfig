"""Small filesystem primitives for activation helpers.

Walk every directory with O_NOFOLLOW and operate relative to its descriptor.
A symlink, including one in a parent directory, is a conflict, never a target.
"""
import contextlib
import fcntl
import os
from pathlib import Path
import secrets
import stat


@contextlib.contextmanager
def parent(path, create=False):
    path = Path(os.path.abspath(path))
    parts = path.parts[1:]
    if not parts:
        raise ValueError("A file path is required")
    fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for name in parts[:-1]:
            if create:
                try:
                    os.mkdir(name, mode=0o755, dir_fd=fd)
                except FileExistsError:
                    pass
            child = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        yield fd, parts[-1]
    finally:
        os.close(fd)


def snapshot(path):
    try:
        with parent(path) as (fd, name):
            file_fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
            with os.fdopen(file_fd, "rb") as stream:
                if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                    raise RuntimeError(f"Not a regular file: {path}")
                info = os.fstat(stream.fileno())
                return stream.read(), [info.st_dev, info.st_ino]
    except FileNotFoundError:
        return None, None


def read(path):
    return snapshot(path)[0]


_UNSPECIFIED = object()


def write(path, content, mode=0o600, expected=_UNSPECIFIED, identity=_UNSPECIFIED, before_commit=None):
    if isinstance(content, str):
        content = content.encode()
    with parent(path, create=True) as (fd, name):
        # Reject existing symlinks and special files, including dangling links.
        try:
            if not stat.S_ISREG(os.stat(name, dir_fd=fd, follow_symlinks=False).st_mode):
                raise RuntimeError(f"Not a regular file: {path}")
        except FileNotFoundError:
            pass
        temporary = f".nixconfig-{secrets.token_hex(12)}"
        file_fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode, dir_fd=fd)
        try:
            with os.fdopen(file_fd, "wb") as stream:
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
                info = os.fstat(stream.fileno())
            if identity is not _UNSPECIFIED and snapshot(path)[1] != identity:
                raise RuntimeError(f"File replaced during update: {path}")
            if expected is not _UNSPECIFIED and read(path) != expected:
                raise RuntimeError(f"File changed during update: {path}")
            if before_commit is not None:
                before_commit([info.st_dev, info.st_ino])
            if expected is None:
                # Atomic create-if-absent: never replace a concurrently created file.
                os.link(temporary, name, src_dir_fd=fd, dst_dir_fd=fd, follow_symlinks=False)
            else:
                os.rename(temporary, name, src_dir_fd=fd, dst_dir_fd=fd)
            os.fsync(fd)
        finally:
            try:
                os.unlink(temporary, dir_fd=fd)
            except FileNotFoundError:
                pass


def remove(path, expected, identity=_UNSPECIFIED):
    # Content must match immediately before removal. Never follow links.
    with parent(path) as (fd, name):
        file_fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        with os.fdopen(file_fd, "rb") as stream:
            info = os.fstat(stream.fileno())
            if identity is not _UNSPECIFIED and [info.st_dev, info.st_ino] != identity:
                raise RuntimeError(f"File replaced during cleanup: {path}")
            if not stat.S_ISREG(info.st_mode) or stream.read() != expected:
                raise RuntimeError(f"Preserving changed file: {path}")
            current = os.stat(name, dir_fd=fd, follow_symlinks=False)
            if (info.st_dev, info.st_ino) != (current.st_dev, current.st_ino):
                raise RuntimeError(f"File replaced during cleanup: {path}")
            os.unlink(name, dir_fd=fd)
            os.fsync(fd)


@contextlib.contextmanager
def lock(path):
    with parent(path, create=True) as (fd, name):
        lock_fd = os.open(name, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600, dir_fd=fd)
        with os.fdopen(lock_fd, "a") as stream:
            if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                raise RuntimeError(f"Not a regular lock file: {path}")
            fcntl.flock(stream, fcntl.LOCK_EX)
            yield
