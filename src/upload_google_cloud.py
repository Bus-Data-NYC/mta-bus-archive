#!/usr/bin/env python
from __future__ import print_function
import sys
from argparse import ArgumentParser
from google.cloud import storage

def main():
    parser = ArgumentParser()
    parser.add_argument('bucket', type=str, help="Google Cloud bucket to upload to. Will create if it doesn't exist")
    parser.add_argument('filename', type=str, help="Local file to upload. Will copy to <bucket> using same path")

    args = parser.parse_args()

    # Read credentials from GOOGLE_APPLICATION_CREDENTIALS environment variable.
    client = storage.Client()

    try:
        bucket = client.get_bucket(args.bucket)
    except storage.exceptions.NotFound:
        bucket = client.create_bucket(args.bucket)

    blob = bucket.blob(args.filename, chunk_size=256)
    blob.upload_from_filename(filename=args.filename)
    print('uploaded', filename, file=sys.stderr)

if __name__ == '__main__':
    main()
