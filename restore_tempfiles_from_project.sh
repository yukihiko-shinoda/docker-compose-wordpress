#!/bin/bash -eu
cp -fpR wordpress-s3/vendor/* /tmp/wordpress/vendor/
cp -fpR wordpress-s3/web/static/* /tmp/wordpress/static/
chmod 775 /tmp/wordpress/static
chown root:nobody /tmp/wordpress/static