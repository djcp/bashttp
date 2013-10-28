#!/bin/bash

log_if_verbose() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo -ne $1
  fi
}

send_response (){
  MIMETYPE=$1
  FILE=$2
  RESPONSE_OBJ=$3

  CONTENT_LENGTH=$(wc -c $FILE | cut -d" " -f1)
  OUTPUT_FILE=$(mktemp -t bashttp.XXXXXXXXXXXXX)
  printf "%s" $"HTTP/1.0 200 OK
Cache-Control: private
Content-Type: $MIMETYPE
Date: $(date -R)
Server: bash/2.0
Connection: Close
Content-Length: $CONTENT_LENGTH

" > $OUTPUT_FILE
 cat $FILE >> $OUTPUT_FILE
 cat $OUTPUT_FILE > $RESPONSE_OBJ && rm $OUTPUT_FILE

}

while true ; do
  RESPONSE=$(mktemp -u -t bashttpresponse.XXXXXXXXXX)
  [ -p $RESPONSE ] || mkfifo $RESPONSE

    ( cat $RESPONSE ) | nc -l -p 8080 | (
    REQUEST=`while read LINE && [ " " "<" "$LINE" ] ; do echo "$LINE" ; done`
    REQ=$(echo "$REQUEST" | head -n1)
    MIMETYPE=''
    FILE=''

    echo "[ `date '+%Y-%m-%d %H:%M:%S'` ] $REQ" >> log/http-access.log

    if [[ $REQ =~ ^GET ]]; then
      FILE=`echo $REQ | cut -d" " -f2`
      FILE=".$FILE"

      if [[ -e $FILE ]]; then
        echo "$FILE FOUND!" >> log/http-access.log
        EXTENSION="${FILE##*.}"
        MIMETYPE=$(grep "	$EXTENSION" /etc/mime.types | head -n1 | cut -f1 -d'	')
        # MIMETYPE=`file -b --mime-type $FILE`;
      else
        echo "$FILE NOT FOUND!" >> log/http-access.log
        MIMETYPE="text/plain"
        RESP="not found"
      fi
    else
      MIMETYPE="text/plain"
      RESP="invalid request"
    fi

    send_response $MIMETYPE $FILE $RESPONSE

    )
    rm $RESPONSE
done
