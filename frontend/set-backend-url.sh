#!/bin/bash

sed -i 's|data-backend-url=\"[^\"]*\"|data-backend-url=\"'"$BACKEND_URL"'\"|' /usr/share/nginx/html/index.html

