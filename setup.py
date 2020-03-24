import setuptools

setuptools.setup(
    name="pg_geocoder",
    version="0.0.1",
    author="Dane Mason",
    author_email="danem.mason@gmail.com",
    description="Fast, local geocoding",
    long_description="Fast, local geocoding",
    long_description_content_type="text/markdown",
    url="https://github.com/danem/pg_geocoder",
    packages=setuptools.find_packages(),
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    include_package_data=True,
    package_data = {'pg_geocoder': ['pg_geocoder/data/country_codes.csv', 'pg_geocoder/data/demonyms.csv']},
    python_requires='>=3.6'
)
