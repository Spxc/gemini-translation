#!/bin/bash
set -e

# Restore inputs
SOURCE_FILE=$1
OUTPUT_DIR=$2
LANG_CODE=$3
MODEL="${4:-gemini-3-flash-preview}" # Fallback if not passed
TARGET_FILE="${OUTPUT_DIR}/${LANG_CODE}.json"

UPLOAD_RESPONSE=$(curl "https://generativelanguage.googleapis.com/upload/v1beta/files?key=${GEMINI_API_KEY}" \
  -H "X-Goog-Upload-Protocol: multipart" \
  -F "metadata={\"file\": {\"display_name\": \"source_json\"}};type=application/json" \
  -F "file=@${SOURCE_FILE};type=text/plain")

FILE_URI=$(echo $UPLOAD_RESPONSE | jq -r '.file.uri')

if [ "$FILE_URI" == "null" ] || [ -z "$FILE_URI" ]; then
  echo "Upload failed! Response: $UPLOAD_RESPONSE"
  exit 1
fi

RESPONSE=$(curl "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}" \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{
    "contents": [{
      "role": "user",
      "parts": [
        {"text": "Translate the attached JSON file into '"$LANG_CODE"'. Maintain exact keys and structure. Return ONLY valid JSON output."},
        {"file_data": {"mime_type": "text/plain", "file_uri": "'$FILE_URI'"}}
      ]
    }],
    "generationConfig": {
      "response_mime_type": "application/json",
      "max_output_tokens": 8192,
      "temperature": 0.1
    }
  }')

EXTRACTED_TEXT=$(echo "$RESPONSE" | jq -r '
  .candidates[0].content.parts[] 
  | select(.text != null) 
  | .text 
  | sub("^```json\\n"; "") 
  | sub("\\n```$"; "") 
  | sub("^```\\n"; "") 
  | sub("```$"; "")
')

if [[ ! "$EXTRACTED_TEXT" =~ ^\{ ]]; then
  echo "Error: Extracted text does not look like JSON. Start of text: ${EXTRACTED_TEXT:0:50}"
  echo "Full Response for Debug:"
  echo "$RESPONSE" | jq .
  exit 1
fi

mkdir -p "$(dirname "$TARGET_FILE")"
echo "$EXTRACTED_TEXT" > "$TARGET_FILE"

echo "✅ Success! Saved to $TARGET_FILE"
