try:
    from setuptools import setup
except ImportError:
    try:
        from distutils.core import setup
    except ImportError:
        import os
        import shutil
        import sys
        import sysconfig

        def _site_packages_dir():
            def normalize(path):
                if not path:
                    return None
                if not os.path.isabs(path):
                    path = os.path.join(sys.prefix, path)
                return os.path.normpath(path)

            for key in ('purelib', 'platlib'):
                candidate = normalize(sysconfig.get_paths().get(key))
                if candidate:
                    try:
                        os.makedirs(candidate, exist_ok=True)
                        return candidate
                    except OSError:
                        pass

            ver = '%d.%d' % sys.version_info[:2]
            fallback = os.path.normpath(
                os.path.join(sys.prefix, 'lib', 'python' + ver, 'site-packages'))
            os.makedirs(fallback, exist_ok=True)
            return fallback

        def setup(**kwargs):
            if len(sys.argv) > 1 and sys.argv[1] == "install":
                dst_dir = _site_packages_dir()
                src_dir = os.path.dirname(os.path.abspath(__file__))
                for mod in kwargs.get("py_modules", []):
                    shutil.copy2(
                        os.path.join(src_dir, mod + ".py"),
                        os.path.join(dst_dir, mod + ".py"))
            else:
                sys.stderr.write("Usage: {0} install\n".format(sys.argv[0]))
                sys.exit(1)

from sys import version
from sys import exit

# earlier versions don't support all classifiers
if version < '2.2.3':
    from distutils.dist import DistributionMetadata
    DistributionMetadata.classifiers = None
    DistributionMetadata.download_url = None

_package_name='nvidia-ml-py'

long_description = None
try:
    # Trying the more correct python3 approach for finding the readme.
    # This will fail with an import error on earlier version of python3 and python2
    # Code is from https://packaging.python.org/en/latest/guides/making-a-pypi-friendly-readme/
    from pathlib import Path
    this_dir = Path(__file__).parent
    long_description = (this_dir / 'README.txt').read_text()
except ImportError:
    # If pathlib can not find the readme, try reading it from the current dir.
    # This should always work if the readme is in the parent directory.
    # This will also work with pytho2.
    try:
        with open('README.txt', 'r') as readme:
            long_description = readme.read()
    except IOError:
        # The python2 error for files that don't exist.
        # Python3 translates this to an OSError.
        pass
    except FileNotFoundError:
        # The Python3 error for files that don't exist.
        # Catching this second since it doesn't exist in python 2
        pass
finally:
    # Exit if there is no long description.
    if long_description is None:
        print('Unable to load README.txt as long description.')
        print('Make sure it is in the correct directory.')
        exit(1)


setup(name=_package_name,
      version='13.615.71',
      description='Python Bindings for the NVIDIA Management Library',
      long_description=long_description,
      long_description_content_type='text/markdown',
      py_modules=['pynvml', 'example'],
      package_data={_package_name: ['Example.txt']},
      license='BSD',
      url='https://forums.developer.nvidia.com',
      author='NVIDIA Corporation',
      author_email='nvml-bindings@nvidia.com',
      classifiers=[
          'Development Status :: 5 - Production/Stable',
          'Intended Audience :: Developers',
          'Intended Audience :: System Administrators',
          'License :: OSI Approved :: BSD License',
          'Operating System :: Microsoft :: Windows',
          'Operating System :: POSIX :: Linux',
          'Programming Language :: Python',
          'Topic :: Software Development :: Libraries :: Python Modules',
          'Topic :: System :: Hardware',
          'Topic :: System :: Systems Administration',
          ],
      )

