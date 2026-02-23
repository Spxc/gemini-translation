#!/bin/bash
set -e

SOURCE_FILE=$1
OUTPUT_DIR=$2
LANG_CODES=$3
MODEL="${4:-gemini-3-flash-preview}"

IFS=', ' read -r -a LANGUAGES <<< "${LANG_CODES//,/ }"

echo "📤 Uploading source file..."
UPLOAD_RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/upload/v1beta/files?key=${GEMINI_API_KEY}" \
  -H "X-Goog-Upload-Protocol: multipart" \
  -F "metadata={\"file\": {\"display_name\": \"source_json\"}};type=application/json" \
  -F "file=@${SOURCE_FILE};type=text/plain")

FILE_URI=$(echo "$UPLOAD_RESPONSE" | jq -r '.file.uri // empty')

if [ -z "$FILE_URI" ]; then
  echo "❌ Upload failed! Response:"
  echo "$UPLOAD_RESPONSE" | jq .
  exit 1
fi

echo "✅ Uploaded: $FILE_URI"

for LANG_CODE in "${LANGUAGES[@]}"; do
  echo "🌍 Translating to $LANG_CODE..."
  TARGET_FILE="${OUTPUT_DIR}/${LANG_CODE}.json"

  RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}" \
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

  API_ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty')
  if [ ! -z "$API_ERROR" ]; then
    echo "❌ API Error: $API_ERROR"
    exit 1
  fi

  EXTRACTED_TEXT=$(echo "$RESPONSE" | jq -r '
    if .candidates and .candidates[0].content and .candidates[0].content.parts then
      .candidates[0].content.parts[0].text
      | sub("^```json\\n"; "") 
      | sub("\\n```$"; "") 
      | sub("^```\\n"; "") 
      | sub("```$"; "")
    else
      empty
    end
  ')

  if [ -z "$EXTRACTED_TEXT" ] || [ "$EXTRACTED_TEXT" == "null" ]; then
    echo "❌ No translation generated for $LANG_CODE. API Response:"
    echo "$RESPONSE" | jq .
    exit 1
  fi

  mkdir -p "$(dirname "$TARGET_FILE")"
  echo "$EXTRACTED_TEXT" > "$TARGET_FILE"
  echo "✅ Saved $TARGET_FILE"

  echo "⏲️ Waiting for rate limit cooldown..."
  sleep 10
done

echo "🚀 All translations completed successfully."
