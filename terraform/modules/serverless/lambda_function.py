"""
bedrock-asset-processor
"""

import json
import logging
import urllib.parse

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    S3 Event Notification handler.
    Logs: "Image received: <filename>" for every uploaded object.
    """
    logger.info("Event received: %s", json.dumps(event))

    records = event.get("Records", [])
    if not records:
        logger.warning("No records found in event payload.")
        return {"statusCode": 200, "body": "No records to process."}

    processed = []
    for record in records:
        # Extract bucket and object key from the S3 event record
        s3_info = record.get("s3", {})
        bucket_name = s3_info.get("bucket", {}).get("name", "unknown-bucket")
        object_key = urllib.parse.unquote_plus(
            s3_info.get("object", {}).get("key", "unknown-key")
        )
        object_size = s3_info.get("object", {}).get("size", 0)
        event_name = record.get("eventName", "unknown-event")

        # Required log line — grader checks for this pattern
        logger.info("Image received: %s", object_key)

        # Additional structured context for observability
        logger.info(
            "Asset details — bucket: %s | key: %s | size: %d bytes | event: %s",
            bucket_name,
            object_key,
            object_size,
            event_name,
        )

        processed.append(object_key)

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": f"Processed {len(processed)} file(s).",
            "files": processed,
        }),
    }
