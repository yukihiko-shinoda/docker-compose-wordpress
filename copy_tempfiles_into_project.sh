#!/bin/bash -eu
cp -fpR /tmp/wordpress/vendor/* wordpress-s3/vendor/
cp -fpR /tmp/wordpress/static/* wordpress-s3/web/static/
