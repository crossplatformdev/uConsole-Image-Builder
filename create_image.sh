#!/bin/bash

# This wrapper simply forwards to the moved legacy script under scripts/old.
exec scripts/old/create_image.sh "$@"
