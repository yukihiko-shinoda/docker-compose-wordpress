#!/bin/bash -eu
rm -rf /tmp/wordpress
mkdir -p /tmp/wordpress/vendor
chmod 2775 /tmp/wordpress/vendor
chown root:nobody /tmp/wordpress/vendor
cp -fR wordpress-s3/vendor/* /tmp/wordpress/vendor/
